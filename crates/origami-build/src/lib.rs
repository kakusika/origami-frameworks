use std::collections::HashMap;
use std::path::PathBuf;

/// Returns the path to the `@origami` Slint UI library directory.
///
/// Discovered dynamically via `DEP_ORIGAMI_UI_DIR` (or legacy `DEP_ORIGAMI_SLINT_UI_DIR`)
/// when `origami` is a Cargo dependency, with fallback to sibling directory layout
/// if called outside standard build flows.
pub fn ui_dir() -> PathBuf {
    for env_var in &["DEP_ORIGAMI_UI_DIR", "DEP_ORIGAMI_SLINT_UI_DIR"] {
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
            "../crates/origami/ui",
            "../origami/ui",
            "../../origami/ui",
            "../../../origami-frameworks/crates/origami/ui",
            "../origami-slint/ui",
            "../../origami-slint/ui",
            "../../../origami-frameworks/origami-slint/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    panic!("origami UI directory not found. Ensure `origami` is a dependency in Cargo.toml.");
}

/// Returns the path to the `@origami-icons` Slint UI library directory.
///
/// Unlike `mobile_ui_dir()`, this panics when missing rather than
/// returning `None`: `origami`'s own `.slint` files unconditionally
/// import `@origami-icons`, so anything that depends on `origami` and
/// compiles its Slint (via `configure()`) needs this too, the same way
/// it needs `origami` itself.
pub fn icons_ui_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("DEP_ORIGAMI_ICONS_UI_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return path;
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../crates/origami-icons/ui",
            "../origami-icons/ui",
            "../../origami-icons/ui",
            "../../../origami-frameworks/crates/origami-icons/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    panic!(
        "origami-icons UI directory not found. Ensure `origami-icons` is a dependency in Cargo.toml."
    );
}

/// Returns the path to the `@origami-mobile` Slint UI library directory,
/// or `None` if the calling crate doesn't depend on `origami-mobile` --
/// unlike `ui_dir()`, this doesn't panic, since most consumers don't need
/// the mobile widgets.
pub fn mobile_ui_dir() -> Option<PathBuf> {
    if let Ok(dir) = std::env::var("DEP_ORIGAMI_MOBILE_UI_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return Some(path);
        }
    }
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../crates/origami-mobile/ui",
            "../origami-mobile/ui",
            "../../origami-mobile/ui",
            "../../../origami-frameworks/crates/origami-mobile/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return Some(candidate);
            }
        }
    }
    None
}

/// Returns a HashMap mapping `"origami"` and `"origami-icons"` to their UI
/// directory paths, plus `"origami-mobile"` too when that's also a
/// dependency.
pub fn library_paths() -> HashMap<String, PathBuf> {
    let mut paths = HashMap::new();
    paths.insert("origami".to_string(), ui_dir());
    paths.insert("origami-icons".to_string(), icons_ui_dir());
    if let Some(mobile_dir) = mobile_ui_dir() {
        paths.insert("origami-mobile".to_string(), mobile_dir);
    }
    paths
}

/// Injects the `@origami` library path into a `slint_build::CompilerConfiguration`.
pub fn configure(config: slint_build::CompilerConfiguration) -> slint_build::CompilerConfiguration {
    config.with_library_paths(library_paths())
}
