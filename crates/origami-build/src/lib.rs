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

/// Returns a HashMap mapping `"origami"` to its UI directory path.
pub fn library_paths() -> HashMap<String, PathBuf> {
    let mut paths = HashMap::new();
    paths.insert("origami".to_string(), ui_dir());
    paths
}

/// Injects the `@origami` library path into a `slint_build::CompilerConfiguration`.
pub fn configure(config: slint_build::CompilerConfiguration) -> slint_build::CompilerConfiguration {
    config.with_library_paths(library_paths())
}
