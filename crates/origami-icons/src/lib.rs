//! Shared icon sets (`ui/icons.slint`, `ui/icons/<set>/*.svg`) for both
//! `origami` (desktop) and `origami-mobile` (touch) -- mostly `UI_DIR`
//! build-time wiring (`build.rs`), same convention as `origami` itself,
//! *plus* one real Rust function ([`icon_svg`]) for a caller that needs to
//! resolve an icon from a runtime string rather than a fixed `.slint` call
//! site -- see `build.rs`'s own doc comment for why that can't just reuse
//! the generated `.slint` globals.

use std::io::Read;

include!(concat!(env!("OUT_DIR"), "/icon_lookup.rs"));

/// Decompressed svg bytes for `pkg`'s `slug` icon (e.g. `icon_svg("tabler",
/// "star")`), or `None` if either isn't vendored.
pub fn icon_svg(pkg: &str, slug: &str) -> Option<Vec<u8>> {
    let compressed = icon_svg_gz(pkg, slug)?;
    let mut out = Vec::new();
    flate2::read::GzDecoder::new(compressed)
        .read_to_end(&mut out)
        .expect("a build-time-compressed icon svg decompresses");
    Some(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_known_tabler_icon_round_trips() {
        let svg = icon_svg("tabler", "star").expect("tabler/star.svg is vendored");
        assert!(String::from_utf8_lossy(&svg).contains("<svg"));
    }

    #[test]
    fn an_unknown_slug_or_pkg_is_none() {
        assert!(icon_svg("tabler", "not-a-real-icon-slug").is_none());
        assert!(icon_svg("not-a-real-pkg", "star").is_none());
    }
}
