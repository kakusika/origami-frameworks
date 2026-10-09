use std::collections::HashMap;
use std::path::PathBuf;

/// Returns the path to the `@origiri` Slint UI library directory.
///
/// Discovered dynamically via `DEP_ORIGIRI_UI_DIR` (or legacy `DEP_ORIGIRI_SLINT_UI_DIR`)
/// when `origiri` is a Cargo dependency, with fallback to sibling directory layout
/// if called outside standard build flows.
pub fn ui_dir() -> PathBuf {
    for env_var in &["DEP_ORIGIRI_UI_DIR", "DEP_ORIGIRI_SLINT_UI_DIR"] {
        if let Ok(dir) = std::env::var(env_var) {
            let path = PathBuf::from(dir);
            if path.exists() {
                return path;
            }
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../crates/origiri/ui",
            "../origiri/ui",
            "../../origiri/ui",
            "../../../origiri-frameworks/crates/origiri/ui",
            "../origiri-slint/ui",
            "../../origiri-slint/ui",
            "../../../origiri-frameworks/origiri-slint/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    panic!("origiri UI directory not found. Ensure `origiri` is a dependency in Cargo.toml.");
}

/// Returns the path to the `@origiri-icons` Slint UI library directory.
///
/// Unlike `mobile_ui_dir()`, this panics when missing rather than
/// returning `None`: `origiri`'s own `.slint` files unconditionally
/// import `@origiri-icons`, so anything that depends on `origiri` and
/// compiles its Slint (via `configure()`) needs this too, the same way
/// it needs `origiri` itself.
pub fn icons_ui_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("DEP_ORIGIRI_ICONS_UI_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return path;
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../crates/origiri-icons/ui",
            "../origiri-icons/ui",
            "../../origiri-icons/ui",
            "../../../origiri-frameworks/crates/origiri-icons/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    panic!(
        "origiri-icons UI directory not found. Ensure `origiri-icons` is a dependency in Cargo.toml."
    );
}

/// Returns the path to the `@origiri-mobile` Slint UI library directory,
/// or `None` if the calling crate doesn't depend on `origiri-mobile` --
/// unlike `ui_dir()`, this doesn't panic, since most consumers don't need
/// the mobile widgets.
pub fn mobile_ui_dir() -> Option<PathBuf> {
    if let Ok(dir) = std::env::var("DEP_ORIGIRI_MOBILE_UI_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return Some(path);
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../crates/origiri-mobile/ui",
            "../origiri-mobile/ui",
            "../../origiri-mobile/ui",
            "../../../origiri-frameworks/crates/origiri-mobile/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return Some(candidate);
            }
        }
    }
    None
}

/// Returns a HashMap mapping `"origiri"` and `"origiri-icons"` to their UI
/// directory paths, plus `"origiri-mobile"` too when that's also a
/// dependency.
pub fn library_paths() -> HashMap<String, PathBuf> {
    let mut paths = HashMap::new();
    paths.insert("origiri".to_string(), ui_dir());
    paths.insert("origiri-icons".to_string(), icons_ui_dir());
    if let Some(mobile_dir) = mobile_ui_dir() {
        paths.insert("origiri-mobile".to_string(), mobile_dir);
    }
    paths
}

/// Injects the `@origiri` library path into a `slint_build::CompilerConfiguration`.
pub fn configure(config: slint_build::CompilerConfiguration) -> slint_build::CompilerConfiguration {
    config.with_library_paths(library_paths())
}
