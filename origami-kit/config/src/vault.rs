//! Load/save which vault is currently active, plus a most-recently-used list
//! of vaults, under the OS-level per-user config directory (`$XDG_CONFIG_HOME/
//! <organization>`, e.g. `~/.config/cettila` on Linux by default, via the
//! `directories` crate and `crate::identity`'s qualifier/organization/
//! application triple -- see that module's own doc comment).
//!
//! This can't live inside `<vault>/.cettila/...` like `settings.rs`/
//! `workspace.rs` do: you'd need to already know which vault is active
//! before you could read that vault's own config file. So it's user-global,
//! like `cache.rs` -- but unlike `cache.rs`'s deliberately-ephemeral "last
//! picked directory" (a re-derivable habit, fine to lose), which vault is
//! active is a durable user choice, so this uses `config_dir()` rather than
//! `cache_dir()`.
//!
//! `active_vault_root()` is the single resolver every crate that used to
//! hardcode `workspace::DEFAULT_VAULT_ROOT` (or duplicate a private
//! `vault_root()` helper around it) should call instead.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use directories::ProjectDirs;
use serde::{Deserialize, Serialize};

use crate::workspace;

/// Most-recently-used vaults kept in `recent_vaults` -- old enough entries
/// fall off the end rather than growing the file forever.
const MAX_RECENT_VAULTS: usize = 10;

/// Where `VaultConfig` is persisted, or `None` if the platform's config
/// directory couldn't be resolved (e.g. no home directory).
pub fn vault_config_path() -> Option<PathBuf> {
    let id = crate::identity::app_identity();
    let dirs = ProjectDirs::from(&id.qualifier, &id.organization, &id.application)?;
    Some(dirs.config_dir().join("vault.toml"))
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct VaultConfig {
    #[serde(skip_serializing_if = "Option::is_none")]
    active_vault: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    recent_vaults: Vec<String>,
}

fn load(path: &Path) -> VaultConfig {
    match fs::read_to_string(path) {
        Ok(content) => toml::from_str(&content).unwrap_or_default(),
        Err(_) => VaultConfig::default(),
    }
}

fn save(path: &Path, config: &VaultConfig) -> io::Result<()> {
    let toml = toml::to_string_pretty(config)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, toml)
}

fn load_default() -> VaultConfig {
    match vault_config_path() {
        Some(path) => load(&path),
        None => VaultConfig::default(),
    }
}

fn save_default(config: &VaultConfig) -> io::Result<()> {
    let path = vault_config_path().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "could not resolve the user config directory",
        )
    })?;
    save(&path, config)
}

/// The vault root every vault-scoped call (settings/workspace load-save,
/// vault-wide scans, ...) should use: the persisted `active_vault` if one has
/// been chosen, otherwise `workspace::DEFAULT_VAULT_ROOT` (the original
/// hardcoded dev-vault default, kept as the zero-config fallback for a
/// first run where no vault has been picked yet).
pub fn active_vault_root() -> PathBuf {
    match load_default().active_vault {
        Some(path) => PathBuf::from(path),
        None => PathBuf::from(workspace::DEFAULT_VAULT_ROOT),
    }
}

/// Vaults the user has previously switched to, most-recent first. For the
/// vault-picker UI's recent-vaults list.
pub fn recent_vaults() -> Vec<PathBuf> {
    load_default()
        .recent_vaults
        .into_iter()
        .map(PathBuf::from)
        .collect()
}

/// Makes `path` the active vault and moves it to the front of the
/// recent-vaults list (removing any earlier occurrence first, so the list
/// stays deduplicated), trimming the list to `MAX_RECENT_VAULTS`.
pub fn set_active_vault(path: &Path) -> io::Result<()> {
    let mut config = load_default();
    let path_str = path.to_string_lossy().into_owned();

    config.recent_vaults.retain(|entry| entry != &path_str);
    config.recent_vaults.insert(0, path_str.clone());
    config.recent_vaults.truncate(MAX_RECENT_VAULTS);

    config.active_vault = Some(path_str);
    save_default(&config)
}

/// Removes `path` from the recent-vaults list only -- doesn't touch which
/// vault is currently active, even if it's the same path (removing a stale
/// entry from the list shouldn't silently switch the active vault away).
pub fn remove_recent_vault(path: &Path) -> io::Result<()> {
    let mut config = load_default();
    let path_str = path.to_string_lossy().into_owned();
    config.recent_vaults.retain(|entry| entry != &path_str);
    save_default(&config)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(label: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-vault-test-{label}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        dir.join("vault.toml")
    }

    #[test]
    fn round_trips_vault_config_through_toml_on_disk() {
        let path = temp_path("roundtrip");

        let loaded = load(&path);
        assert_eq!(loaded.active_vault, None);
        assert!(loaded.recent_vaults.is_empty());

        let mut config = VaultConfig::default();
        config.active_vault = Some("/home/user/notes".to_string());
        config.recent_vaults = vec!["/home/user/notes".to_string()];
        save(&path, &config).unwrap();

        let loaded = load(&path);
        assert_eq!(loaded.active_vault, Some("/home/user/notes".to_string()));
        assert_eq!(loaded.recent_vaults, vec!["/home/user/notes".to_string()]);

        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn set_active_vault_deduplicates_and_moves_to_front() {
        let path = temp_path("dedup");

        let mut config = VaultConfig::default();
        config.recent_vaults = vec!["/a".to_string(), "/b".to_string(), "/c".to_string()];
        save(&path, &config).unwrap();

        // Simulate set_active_vault's logic against this temp path directly,
        // since set_active_vault itself always resolves the real
        // platform-wide config path via vault_config_path().
        let mut config = load(&path);
        let path_str = "/b".to_string();
        config.recent_vaults.retain(|entry| entry != &path_str);
        config.recent_vaults.insert(0, path_str.clone());
        config.active_vault = Some(path_str);
        save(&path, &config).unwrap();

        let loaded = load(&path);
        assert_eq!(loaded.active_vault, Some("/b".to_string()));
        assert_eq!(
            loaded.recent_vaults,
            vec!["/b".to_string(), "/a".to_string(), "/c".to_string()]
        );

        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn set_active_vault_trims_recent_vaults_to_max() {
        let path = temp_path("trim");

        let mut config = VaultConfig::default();
        for i in 0..MAX_RECENT_VAULTS {
            config.recent_vaults.push(format!("/vault{i}"));
        }
        save(&path, &config).unwrap();

        let mut config = load(&path);
        let path_str = "/vault-new".to_string();
        config.recent_vaults.retain(|entry| entry != &path_str);
        config.recent_vaults.insert(0, path_str.clone());
        config.recent_vaults.truncate(MAX_RECENT_VAULTS);
        save(&path, &config).unwrap();

        let loaded = load(&path);
        assert_eq!(loaded.recent_vaults.len(), MAX_RECENT_VAULTS);
        assert_eq!(loaded.recent_vaults[0], "/vault-new");

        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn vault_config_path_ends_with_cettila_vault_toml() {
        let path =
            vault_config_path().expect("config dir should resolve on a machine with a home dir");
        assert_eq!(path.file_name().unwrap(), "vault.toml");
        assert_eq!(path.parent().unwrap().file_name().unwrap(), "cettila");
    }
}
