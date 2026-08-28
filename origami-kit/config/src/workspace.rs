//! Load/save the pane workspace layout (split/tab tree, per-tab properties)
//! under a vault's `.cettila/workspaces/` directory.
//!
//! This module treats the workspace content as an opaque JSON value with no
//! knowledge of pane/split/leaf semantics -- that shape lives entirely in
//! `PaneView.qml` (the only place with enough context to map a view-type
//! string back to a QML `Component`), so callers just hand this module a JSON
//! string and get one back. On disk it's stored as YAML -- unlike
//! `settings.rs`/`cache.rs`, which moved to TOML, this stays YAML since the
//! pane tree can contain JSON `null` (e.g. an unset optional prop), which
//! TOML has no representation for.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

/// Hardcoded dev-vault root -- the zero-config fallback `vault::
/// active_vault_root()` (see `crate::vault`) resolves to before the user has
/// ever picked a vault via the vault-picker (`Origami.VaultManager`/
/// `VaultPickerDialog.qml`). `fs_entries::default_root()` (`origami` crate)
/// resolves through that same function, so it always matches whichever
/// vault is actually active rather than this constant directly.
pub const DEFAULT_VAULT_ROOT: &str =
    "/home/tefla/projects/develop/cettila-projects/cettila/sandbox";

pub fn workspace_path(vault_root: &Path) -> PathBuf {
    vault_root
        .join(".cettila")
        .join("workspaces")
        .join("workspace.yaml")
}

/// Reads the saved workspace as a JSON string, or `None` if there's nothing
/// saved yet (missing file) or the file couldn't be parsed.
pub fn load_workspace_json(vault_root: &Path) -> Option<String> {
    let path = workspace_path(vault_root);
    let content = fs::read_to_string(&path).ok()?;
    // serde_yaml can deserialize into any Deserialize type, including
    // serde_json::Value, since both go through serde's generic data model --
    // no custom YAML<->JSON conversion needed.
    let value: serde_json::Value = match serde_yaml::from_str(&content) {
        Ok(value) => value,
        Err(err) => {
            eprintln!("cettila-config: failed to parse {}: {err}", path.display());
            return None;
        }
    };
    serde_json::to_string(&value).ok()
}

/// Parses `json` and writes it to the vault's workspace file as YAML,
/// creating `.cettila/workspaces/` if needed.
pub fn save_workspace_json(vault_root: &Path, json: &str) -> io::Result<()> {
    let value: serde_json::Value = serde_json::from_str(json)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;
    let yaml = serde_yaml::to_string(&value)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;

    let path = workspace_path(vault_root);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, yaml)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_through_yaml_on_disk() {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-workspace-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();

        assert_eq!(load_workspace_json(&dir), None);

        let json = r#"{"type":"leaf","tabs":[{"viewType":"explorer","title":"Explorer","props":{}}],"currentIndex":0}"#;
        save_workspace_json(&dir, json).unwrap();

        let loaded = load_workspace_json(&dir).expect("workspace should now load");
        let expected: serde_json::Value = serde_json::from_str(json).unwrap();
        let actual: serde_json::Value = serde_json::from_str(&loaded).unwrap();
        assert_eq!(actual, expected);

        assert!(workspace_path(&dir).exists());

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn rejects_invalid_json_on_save() {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-workspace-test-invalid-{}",
            std::process::id()
        ));
        let result = save_workspace_json(&dir, "not json");
        assert!(result.is_err());
    }

    #[test]
    fn round_trips_nulls_since_yaml_has_null() {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-workspace-test-nulls-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();

        let json = r#"{"type":"leaf","title":null,"tabs":[{"viewType":"explorer"},null]}"#;
        save_workspace_json(&dir, json).unwrap();

        let loaded = load_workspace_json(&dir).expect("workspace should now load");
        let actual: serde_json::Value = serde_json::from_str(&loaded).unwrap();
        let expected: serde_json::Value = serde_json::from_str(json).unwrap();
        assert_eq!(actual, expected);

        fs::remove_dir_all(&dir).unwrap();
    }
}
