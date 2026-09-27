//! Load/save the pane workspace layout (split/tab tree, per-tab properties)
//! under a vault's `<namespace>/workspaces/` directory (`.cettila/workspaces/` by default, see `crate::identity`).
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
    "/home/user/projects/develop/cettila-projects/cettila/sandbox";

/// The directory a vault keeps its workspace files in: `<vault>/<app's vault namespace>/workspaces/` (`.cettila`
/// unless the app set its own identity, see `crate::identity`).
pub fn workspaces_dir(vault_root: &Path) -> PathBuf {
    vault_root
        .join(&crate::identity::app_identity().vault_namespace)
        .join("workspaces")
}

/// The pane tree.
pub fn workspace_path(vault_root: &Path) -> PathBuf {
    workspaces_dir(vault_root).join("workspace.yaml")
}

/// What belongs to the app's session rather than to the pane tree (which leaf is active, the window's size, ...),
/// kept beside it so `workspace.yaml` stays the bare tree.
pub fn session_path(vault_root: &Path) -> PathBuf {
    workspaces_dir(vault_root).join("session.yaml")
}

fn load_json_at(path: &Path) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    // serde_yaml can deserialize into any Deserialize type, including
    // serde_json::Value, since both go through serde's generic data model --
    // no custom YAML<->JSON conversion needed.
    let value: serde_json::Value = match serde_yaml::from_str(&content) {
        Ok(value) => value,
        Err(err) => {
            eprintln!("origami-config: failed to parse {}: {err}", path.display());
            return None;
        }
    };
    serde_json::to_string(&value).ok()
}

/// Writes through a temporary file and a rename, so a crash mid-write leaves the previous file rather than half
/// of a new one (the workspace is saved often, and while the app is closing).
fn save_json_at(path: &Path, json: &str) -> io::Result<()> {
    let value: serde_json::Value = serde_json::from_str(json)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;
    let yaml = serde_yaml::to_string(&value)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("yaml.tmp");
    fs::write(&tmp, yaml)?;
    fs::rename(&tmp, path)
}

/// Reads the saved workspace as a JSON string, or `None` if there's nothing
/// saved yet (missing file) or the file couldn't be parsed.
pub fn load_workspace_json(vault_root: &Path) -> Option<String> {
    load_json_at(&workspace_path(vault_root))
}

/// Parses `json` and writes it to the vault's workspace file as YAML,
/// creating the workspaces directory if needed.
pub fn save_workspace_json(vault_root: &Path, json: &str) -> io::Result<()> {
    save_json_at(&workspace_path(vault_root), json)
}

/// The saved session (see [`session_path`]) as a JSON string, or `None` if there is none or it is unreadable.
pub fn load_session_json(vault_root: &Path) -> Option<String> {
    load_json_at(&session_path(vault_root))
}

pub fn save_session_json(vault_root: &Path, json: &str) -> io::Result<()> {
    save_json_at(&session_path(vault_root), json)
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

    #[test]
    fn files_live_under_the_apps_vault_namespace() {
        let root = Path::new("/vault");
        let ns = &crate::identity::app_identity().vault_namespace;
        assert_eq!(workspace_path(root), root.join(ns).join("workspaces").join("workspace.yaml"));
        assert_eq!(session_path(root), root.join(ns).join("workspaces").join("session.yaml"));
    }

    #[test]
    fn the_session_is_its_own_file_and_a_save_leaves_no_temporary_file() {
        let dir = std::env::temp_dir().join(format!(
            "origami-config-session-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()
        ));
        assert_eq!(load_session_json(&dir), None);

        save_workspace_json(&dir, r#"{"type":"pane"}"#).unwrap();
        save_session_json(&dir, r#"{"activeLeafId":3}"#).unwrap();
        save_session_json(&dir, r#"{"activeLeafId":4}"#).unwrap();

        let session: serde_json::Value = serde_json::from_str(&load_session_json(&dir).unwrap()).unwrap();
        assert_eq!(session["activeLeafId"], 4);
        let tree: serde_json::Value = serde_json::from_str(&load_workspace_json(&dir).unwrap()).unwrap();
        assert_eq!(tree["type"], "pane");
        let names: Vec<_> = fs::read_dir(workspaces_dir(&dir)).unwrap().map(|e| e.unwrap().file_name()).collect();
        assert_eq!(names.len(), 2, "only workspace.yaml and session.yaml: {names:?}");

        fs::remove_dir_all(&dir).unwrap();
    }
}
