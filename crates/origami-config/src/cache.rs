//! Load/save transient "last used" state under the OS-level per-user cache
//! directory (`$XDG_CACHE_HOME/cettila`, i.e. `~/.cache/cettila` on Linux,
//! via the `directories` crate -- same `("dev", "cettila", "cettila")`
//! qualifier/organization/application triple `cettila/apps/tests/core`'s
//! config loader already uses). Unlike `settings.rs`'s durable per-vault
//! preferences, this is user-global (a "last picked directory" is a habit
//! of the person, not the vault) and re-derivable/re-populated by normal
//! use -- a picker just falls back to `workspace::DEFAULT_VAULT_ROOT` the
//! first time -- so losing it isn't a big deal, unlike `settings.rs`'s
//! `background_cache_path`, which stays vault-relative since it's a
//! precomputed artifact tied to that vault's own background image.

use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;

use directories::ProjectDirs;
use serde::{Deserialize, Serialize};

/// Where `PickDirs` is persisted, or `None` if the platform's cache
/// directory couldn't be resolved (e.g. no home directory).
pub fn pick_dirs_path() -> Option<PathBuf> {
    let dirs = ProjectDirs::from("dev", "cettila", "cettila")?;
    Some(dirs.cache_dir().join("pick_dirs.toml"))
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct PickDirs {
    #[serde(skip_serializing_if = "Option::is_none")]
    last_image_pick_dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_media_pick_dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_json_pick_dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    last_text_pick_dir: Option<String>,
}

fn load(path: &Path) -> PickDirs {
    match fs::read_to_string(path) {
        Ok(content) => toml::from_str(&content).unwrap_or_default(),
        Err(_) => PickDirs::default(),
    }
}

fn save(path: &Path, pick_dirs: &PickDirs) -> io::Result<()> {
    let toml = toml::to_string_pretty(pick_dirs)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, toml)
}

/// Loads `PickDirs` from the real, platform-resolved cache path, or the
/// default (all `None`) if that path couldn't be resolved.
fn load_default() -> PickDirs {
    match pick_dirs_path() {
        Some(path) => load(&path),
        None => PickDirs::default(),
    }
}

/// Saves `PickDirs` to the real, platform-resolved cache path.
fn save_default(pick_dirs: &PickDirs) -> io::Result<()> {
    let path = pick_dirs_path().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::NotFound,
            "could not resolve the user cache directory",
        )
    })?;
    save(&path, pick_dirs)
}

/// The directory `ImagePickerDialog.qml` (cettila-view-explorer --
/// migrated there from cettila-view-origami, see
/// `crates/views/explorer`'s `TASKS.md` for the reasoning) last navigated
/// to, or `None` if it hasn't been used yet (in which case the picker
/// falls back to `workspace::DEFAULT_VAULT_ROOT`). Applied live -- each
/// navigation persists immediately, unlike `settings::load_style`.
pub fn load_last_image_pick_dir() -> Option<String> {
    load_default().last_image_pick_dir
}

pub fn save_last_image_pick_dir(dir: &str) -> io::Result<()> {
    let mut pick_dirs = load_default();
    pick_dirs.last_image_pick_dir = Some(dir.to_string());
    save_default(&pick_dirs)
}

/// The directory `MediaPickerDialog.qml` (cettila-view-explorer, same
/// migration as `last_image_pick_dir` above) last navigated to, or `None`
/// if it hasn't been used yet. Separate key from `last_image_pick_dir`
/// since it's a different picker (image *or* video files, used by
/// cettila-view-preview) with its own independent "last used" location.
pub fn load_last_media_pick_dir() -> Option<String> {
    load_default().last_media_pick_dir
}

pub fn save_last_media_pick_dir(dir: &str) -> io::Result<()> {
    let mut pick_dirs = load_default();
    pick_dirs.last_media_pick_dir = Some(dir.to_string());
    save_default(&pick_dirs)
}

/// The directory `SaveOpenFileDialogPair.qml` (cettila-view-explorer)
/// last saved to or opened from, or `None` if it hasn't been used yet.
/// Shared between its own save and open windows (both browse the same
/// general "JSON export" area of the vault) rather than two separate
/// keys, unlike `last_image_pick_dir`/`last_media_pick_dir`'s own genuine
/// picker-identity split.
pub fn load_last_json_pick_dir() -> Option<String> {
    load_default().last_json_pick_dir
}

pub fn save_last_json_pick_dir(dir: &str) -> io::Result<()> {
    let mut pick_dirs = load_default();
    pick_dirs.last_json_pick_dir = Some(dir.to_string());
    save_default(&pick_dirs)
}

/// The directory `TextFilePickerDialog.qml` (cettila-view-explorer, used by
/// cettila-view-text-editor's "ファイル > 開く..." menu entry) last
/// navigated to, or `None` if it hasn't been used yet. Separate key from
/// `last_image_pick_dir`/`last_media_pick_dir`/`last_json_pick_dir`, same
/// "genuine picker-identity split" reasoning as those.
pub fn load_last_text_pick_dir() -> Option<String> {
    load_default().last_text_pick_dir
}

pub fn save_last_text_pick_dir(dir: &str) -> io::Result<()> {
    let mut pick_dirs = load_default();
    pick_dirs.last_text_pick_dir = Some(dir.to_string());
    save_default(&pick_dirs)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(label: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-cache-test-{label}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        dir.join("pick_dirs.toml")
    }

    #[test]
    fn round_trips_pick_dirs_through_toml_on_disk() {
        let path = temp_path("roundtrip");

        let loaded = load(&path);
        assert_eq!(loaded.last_image_pick_dir, None);
        assert_eq!(loaded.last_media_pick_dir, None);
        assert_eq!(loaded.last_json_pick_dir, None);
        assert_eq!(loaded.last_text_pick_dir, None);

        let mut pick_dirs = PickDirs::default();
        pick_dirs.last_image_pick_dir = Some("/home/user/Pictures".to_string());
        pick_dirs.last_media_pick_dir = Some("/home/user/Videos".to_string());
        save(&path, &pick_dirs).unwrap();

        let loaded = load(&path);
        assert_eq!(
            loaded.last_image_pick_dir,
            Some("/home/user/Pictures".to_string())
        );
        assert_eq!(
            loaded.last_media_pick_dir,
            Some("/home/user/Videos".to_string())
        );
        assert_eq!(loaded.last_json_pick_dir, None);
        assert_eq!(loaded.last_text_pick_dir, None);

        fs::remove_dir_all(path.parent().unwrap()).unwrap();
    }

    #[test]
    fn pick_dirs_path_ends_with_cettila_pick_dirs_toml() {
        let path = pick_dirs_path().expect("cache dir should resolve on a machine with a home dir");
        assert_eq!(path.file_name().unwrap(), "pick_dirs.toml");
        assert_eq!(path.parent().unwrap().file_name().unwrap(), "cettila");
    }
}
