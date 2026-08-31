use std::collections::HashMap;
use std::path::PathBuf;

/// Returns the path to the `@ayame` Slint UI library directory.
///
/// Discovered dynamically via `DEP_AYAME_SLINT_UI_DIR` when `ayame-slint` is a Cargo
/// dependency, with fallback to sibling directory layout if called outside standard build flows.
pub fn ui_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("DEP_AYAME_SLINT_UI_DIR") {
        let path = PathBuf::from(dir);
        if path.exists() {
            return path;
        }
    }
    // Fallback: check relative to CARGO_MANIFEST_DIR if available
    if let Ok(manifest) = std::env::var("CARGO_MANIFEST_DIR") {
        let manifest_path = PathBuf::from(manifest);
        for rel in &[
            "../../ayame/slint/ui",
            "../../../ayame/slint/ui",
            "../slint/ui",
        ] {
            let candidate = manifest_path.join(rel);
            if candidate.exists() {
                return candidate;
            }
        }
    }
    panic!(
        "ayame-slint UI directory not found. Ensure `ayame-slint` is a dependency in Cargo.toml."
    );
}

/// Returns a HashMap mapping `"ayame"` to its UI directory path.
pub fn library_paths() -> HashMap<String, PathBuf> {
    let mut paths = HashMap::new();
    paths.insert("ayame".to_string(), ui_dir());
    paths
}

/// Injects `@ayame` library paths into a `slint_build::CompilerConfiguration`.
pub fn configure(config: slint_build::CompilerConfiguration) -> slint_build::CompilerConfiguration {
    config.with_library_paths(library_paths())
}
