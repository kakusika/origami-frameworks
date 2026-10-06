//! Named color scheme registry: Origami's own light/dark presets plus a
//! handful of well-known editor color schemes (TokyoNight, Catppuccin,
//! Flexoki), each split into "scheme" (e.g. "Catppuccin") and "variant"
//! (e.g. "Mocha").
//!
//! Every non-Origami variant's base colors and `default_accent` are ported
//! from that project's own published palette (see doc comments below for
//! exact sources) using one fixed mapping rule, since none of these
//! projects define Qt `QPalette` roles themselves:
//! - `base` = the scheme's main content background.
//! - `window`/`button` = a distinct chrome background one shade off from
//!   `base`, where the source provides one (e.g. Catppuccin's Mantle,
//!   TokyoNight's `bg_dark`); reused from `base` where it doesn't
//!   (Flexoki, TokyoNight Day) -- noted per variant, not silently
//!   fabricated.
//! - `text`/`window_text`/`button_text` = the scheme's main foreground.
//! - `alternate_base` = a secondary surface shade where available
//!   (Catppuccin's Surface0, TokyoNight's `bg_highlight`), else reused
//!   from `base`.
//! - `tooltip_base`/`tooltip_text` = same as `window`/`text`.
//! - `light` (QPalette::Light, a bevel-highlight shade lighter than
//!   `window`) = white for light-mode variants (matching Origami's own
//!   `LIGHT_PRESET`), or the scheme's own lighter secondary
//!   surface/foreground shade for dark-mode variants.

mod blender;
mod catppuccin;
mod flexoki;
mod origami;
mod tokyonight;

use super::{PalettePreset, RgbColor};

use blender::BLENDER_VARIANTS;
use catppuccin::CATPPUCCIN_VARIANTS;
use flexoki::FLEXOKI_VARIANTS;
use origami::ORIGAMI_VARIANTS;
use tokyonight::TOKYONIGHT_VARIANTS;

/// One selectable palette within a `SchemeInfo`, e.g. Catppuccin's Mocha.
/// `id` is the flat, persisted identifier (`origami_config::settings`'s
/// `theme_mode` value) -- see `super::preset_by_id`'s doc comment for the
/// backward-compatibility reasoning behind why Origami's own variants keep
/// bare `"light"`/`"dark"` ids while every other scheme's ids are
/// `"<scheme>-<variant>"`.
pub struct VariantInfo {
    pub id: &'static str,
    pub name: &'static str,
    pub preset: PalettePreset,
    pub default_accent: RgbColor,
}

pub struct SchemeInfo {
    pub id: &'static str,
    pub name: &'static str,
    pub variants: &'static [VariantInfo],
}

pub const SCHEMES: &[SchemeInfo] = &[
    SchemeInfo {
        id: "origami",
        name: "Origami",
        variants: ORIGAMI_VARIANTS,
    },
    SchemeInfo {
        id: "blender",
        name: "Blender",
        variants: BLENDER_VARIANTS,
    },
    SchemeInfo {
        id: "tokyonight",
        name: "TokyoNight",
        variants: TOKYONIGHT_VARIANTS,
    },
    SchemeInfo {
        id: "catppuccin",
        name: "Catppuccin",
        variants: CATPPUCCIN_VARIANTS,
    },
    SchemeInfo {
        id: "flexoki",
        name: "Flexoki",
        variants: FLEXOKI_VARIANTS,
    },
];

/// Finds the variant matching a flat, persisted id (e.g. `"dark"`,
/// `"catppuccin-mocha"`), searching every scheme's variant list.
pub fn find_variant(id: &str) -> Option<&'static VariantInfo> {
    SCHEMES
        .iter()
        .flat_map(|scheme| scheme.variants.iter())
        .find(|variant| variant.id == id)
}

/// Finds which scheme a flat variant id belongs to.
pub fn scheme_of(id: &str) -> Option<&'static str> {
    SCHEMES
        .iter()
        .find(|scheme| scheme.variants.iter().any(|variant| variant.id == id))
        .map(|scheme| scheme.id)
}

pub fn scheme_by_id(id: &str) -> Option<&'static SchemeInfo> {
    SCHEMES.iter().find(|scheme| scheme.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::palette::{DARK_PRESET, LIGHT_PRESET};

    #[test]
    fn every_variant_id_is_findable_and_belongs_to_its_own_scheme() {
        for scheme in SCHEMES {
            for variant in scheme.variants {
                assert_eq!(find_variant(variant.id).map(|v| v.id), Some(variant.id));
                assert_eq!(scheme_of(variant.id), Some(scheme.id));
            }
        }
    }

    #[test]
    fn variant_ids_are_globally_unique() {
        let mut ids: Vec<&str> = SCHEMES
            .iter()
            .flat_map(|scheme| scheme.variants.iter())
            .map(|variant| variant.id)
            .collect();
        let total = ids.len();
        ids.sort_unstable();
        ids.dedup();
        assert_eq!(ids.len(), total, "duplicate variant id in SCHEMES");
    }

    #[test]
    fn unknown_id_is_not_found() {
        assert!(find_variant("system").is_none());
        assert!(find_variant("nonexistent").is_none());
        assert!(scheme_of("system").is_none());
    }

    #[test]
    fn origami_variants_still_use_the_original_presets() {
        assert_eq!(find_variant("light").unwrap().preset, LIGHT_PRESET);
        assert_eq!(find_variant("dark").unwrap().preset, DARK_PRESET);
    }

    #[test]
    fn scheme_by_id_finds_every_registered_scheme() {
        for scheme in SCHEMES {
            assert_eq!(scheme_by_id(scheme.id).map(|s| s.id), Some(scheme.id));
        }
    }
}
