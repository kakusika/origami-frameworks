//! Generic, freedesktop-named, tintable UI icons bundled as vendored
//! Tabler Icons SVGs, so icon rendering is byte-identical across
//! Linux/Windows/macOS regardless of QQC2 style or desktop-installed
//! icon theme. Not app logos -- each app keeps its own in its own repo.
//!
//! The Qt resource itself (`qrc:/cettila/icons/<name>.svg`) is wired up
//! entirely in `build.rs`; this crate's Rust API is just [`MAPPING`].
//! See `../../docs/bundled-icons.md` for the full picture, including a
//! gotcha `build.rs` alone can't solve: depending on this crate from
//! Cargo isn't enough by itself for the resource to actually end up
//! linked into a consumer binary.

mod mapping;

pub use mapping::MAPPING;

#[used]
pub static MAPPING_STATIC: &[(&str, &str)] = mapping::MAPPING;

/// Absolute path to the vendored Tabler Icons SVG directory (`vendor/
/// tabler-icons/outline`), valid regardless of the `qt-resource` feature
/// -- baked in via `env!("CARGO_MANIFEST_DIR")` at this crate's own
/// compile time, so it resolves correctly wherever Cargo actually checked
/// this crate out (a plain path dependency or a git dependency's cache
/// alike). A Qt-free consumer (`default-features = false`, e.g. a Slint
/// app) combines this with [`MAPPING`] to resolve a freedesktop-style
/// name to an actual `.svg` file on disk -- e.g. to vendor an individual
/// copy into its own build, the way `cettila-slint` already does today --
/// without needing the `qt-resource` feature's Qt build step at all.
pub fn vendor_dir() -> &'static std::path::Path {
    std::path::Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/vendor/tabler-icons/outline"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vendor_dir_points_at_every_mapped_svg() {
        let dir = vendor_dir();
        assert!(dir.is_dir(), "{dir:?} should exist");
        for (_, tabler_name) in MAPPING {
            let svg = dir.join(format!("{tabler_name}.svg"));
            assert!(svg.is_file(), "{svg:?} should exist (from MAPPING)");
        }
    }
}
