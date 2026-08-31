//! Named color scheme registry: Ayame's own light/dark presets plus a
//! handful of well-known editor color schemes (TokyoNight, Catppuccin,
//! Flexoki), each split into "scheme" (e.g. "Catppuccin") and "variant"
//! (e.g. "Mocha").
//!
//! Every non-Ayame variant's base colors and `default_accent` are ported
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
//!   `window`) = white for light-mode variants (matching Ayame's own
//!   `LIGHT_PRESET`), or the scheme's own lighter secondary
//!   surface/foreground shade for dark-mode variants.

use crate::{DARK_PRESET, LIGHT_PRESET, PalettePreset, RgbColor};

/// One selectable palette within a `SchemeInfo`, e.g. Catppuccin's Mocha.
/// `id` is the flat, persisted identifier (`origami_config::settings`'s
/// `theme_mode` value) -- see `crate::preset_by_id`'s doc comment for the
/// backward-compatibility reasoning behind why Ayame's own variants keep
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

const AYAME_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "light",
        name: "ライト",
        preset: LIGHT_PRESET,
        default_accent: crate::DEFAULT_ACCENT,
    },
    VariantInfo {
        id: "dark",
        name: "ダーク",
        preset: DARK_PRESET,
        default_accent: crate::DEFAULT_ACCENT,
    },
];

// Source: github.com/folke/tokyonight.nvim, `lua/tokyonight/colors/storm.lua`
// and `colors/night.lua` (bg/bg_dark/bg_highlight/fg/fg_dark/blue), and the
// project's own exported `extras/alacritty/tokyonight_day.toml` for Day
// (its Lua source computes Day by inverting Night at runtime, so the
// maintained Alacritty export is the only fixed-literal source available).
// Night only overrides `bg`/`bg_dark` on top of Storm in the upstream Lua,
// so its other roles below are Storm's values, not independently sourced.
const TOKYONIGHT_STORM: PalettePreset = PalettePreset {
    window: RgbColor::new(0x1f, 0x23, 0x35),         // bg_dark
    window_text: RgbColor::new(0xc0, 0xca, 0xf5),    // fg
    base: RgbColor::new(0x24, 0x28, 0x3b),           // bg
    alternate_base: RgbColor::new(0x29, 0x2e, 0x42), // bg_highlight
    text: RgbColor::new(0xc0, 0xca, 0xf5),           // fg
    button: RgbColor::new(0x1f, 0x23, 0x35),         // bg_dark
    button_text: RgbColor::new(0xc0, 0xca, 0xf5),    // fg
    tooltip_base: RgbColor::new(0x1f, 0x23, 0x35),   // bg_dark
    tooltip_text: RgbColor::new(0xc0, 0xca, 0xf5),   // fg
    light: RgbColor::new(0xa9, 0xb1, 0xd6),          // fg_dark
};

const TOKYONIGHT_NIGHT: PalettePreset = PalettePreset {
    window: RgbColor::new(0x16, 0x16, 0x1e),       // bg_dark
    base: RgbColor::new(0x1a, 0x1b, 0x26),         // bg
    button: RgbColor::new(0x16, 0x16, 0x1e),       // bg_dark
    tooltip_base: RgbColor::new(0x16, 0x16, 0x1e), // bg_dark
    ..TOKYONIGHT_STORM
};

const TOKYONIGHT_DAY: PalettePreset = PalettePreset {
    // No distinct `bg_dark`/`bg_highlight` literal was available for Day
    // (only bg/fg/blue are published via the Alacritty export) -- window/
    // alternate_base/tooltip_base reuse `base` rather than guessing a shade.
    window: RgbColor::new(0xe1, 0xe2, 0xe7),         // bg
    window_text: RgbColor::new(0x37, 0x60, 0xbf),    // fg
    base: RgbColor::new(0xe1, 0xe2, 0xe7),           // bg
    alternate_base: RgbColor::new(0xe1, 0xe2, 0xe7), // bg
    text: RgbColor::new(0x37, 0x60, 0xbf),           // fg
    button: RgbColor::new(0xe1, 0xe2, 0xe7),         // bg
    button_text: RgbColor::new(0x37, 0x60, 0xbf),    // fg
    tooltip_base: RgbColor::new(0xe1, 0xe2, 0xe7),   // bg
    tooltip_text: RgbColor::new(0x37, 0x60, 0xbf),   // fg
    light: RgbColor::new(0xff, 0xff, 0xff),
};

const TOKYONIGHT_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "tokyonight-storm",
        name: "Storm",
        preset: TOKYONIGHT_STORM,
        default_accent: RgbColor::new(0x7a, 0xa2, 0xf7), // blue
    },
    VariantInfo {
        id: "tokyonight-night",
        name: "Night",
        preset: TOKYONIGHT_NIGHT,
        default_accent: RgbColor::new(0x7a, 0xa2, 0xf7), // blue (inherited from storm)
    },
    VariantInfo {
        id: "tokyonight-day",
        name: "Day",
        preset: TOKYONIGHT_DAY,
        default_accent: RgbColor::new(0x2e, 0x7d, 0xe9), // blue
    },
];

// Source: github.com/catppuccin/catppuccin's own README palette table
// (Base/Mantle/Text/Surface0/Surface2 per flavor). Default accent is Mauve
// in every flavor -- the color most associated with Catppuccin's own
// branding.
const CATPPUCCIN_LATTE: PalettePreset = PalettePreset {
    window: RgbColor::new(0xe6, 0xe9, 0xef),         // mantle
    window_text: RgbColor::new(0x4c, 0x4f, 0x69),    // text
    base: RgbColor::new(0xef, 0xf1, 0xf5),           // base
    alternate_base: RgbColor::new(0xcc, 0xd0, 0xda), // surface0
    text: RgbColor::new(0x4c, 0x4f, 0x69),
    button: RgbColor::new(0xe6, 0xe9, 0xef), // mantle
    button_text: RgbColor::new(0x4c, 0x4f, 0x69),
    tooltip_base: RgbColor::new(0xe6, 0xe9, 0xef), // mantle
    tooltip_text: RgbColor::new(0x4c, 0x4f, 0x69),
    light: RgbColor::new(0xff, 0xff, 0xff), // light-mode variant convention
};

const CATPPUCCIN_FRAPPE: PalettePreset = PalettePreset {
    window: RgbColor::new(0x29, 0x2c, 0x3c),         // mantle
    window_text: RgbColor::new(0xc6, 0xd0, 0xf5),    // text
    base: RgbColor::new(0x30, 0x34, 0x46),           // base
    alternate_base: RgbColor::new(0x41, 0x45, 0x59), // surface0
    text: RgbColor::new(0xc6, 0xd0, 0xf5),
    button: RgbColor::new(0x29, 0x2c, 0x3c),
    button_text: RgbColor::new(0xc6, 0xd0, 0xf5),
    tooltip_base: RgbColor::new(0x29, 0x2c, 0x3c),
    tooltip_text: RgbColor::new(0xc6, 0xd0, 0xf5),
    light: RgbColor::new(0x62, 0x68, 0x80), // surface2
};

const CATPPUCCIN_MACCHIATO: PalettePreset = PalettePreset {
    window: RgbColor::new(0x1e, 0x20, 0x30),         // mantle
    window_text: RgbColor::new(0xca, 0xd3, 0xf5),    // text
    base: RgbColor::new(0x24, 0x27, 0x3a),           // base
    alternate_base: RgbColor::new(0x36, 0x3a, 0x4f), // surface0
    text: RgbColor::new(0xca, 0xd3, 0xf5),
    button: RgbColor::new(0x1e, 0x20, 0x30),
    button_text: RgbColor::new(0xca, 0xd3, 0xf5),
    tooltip_base: RgbColor::new(0x1e, 0x20, 0x30),
    tooltip_text: RgbColor::new(0xca, 0xd3, 0xf5),
    light: RgbColor::new(0x5b, 0x60, 0x78), // surface2
};

const CATPPUCCIN_MOCHA: PalettePreset = PalettePreset {
    window: RgbColor::new(0x18, 0x18, 0x25),         // mantle
    window_text: RgbColor::new(0xcd, 0xd6, 0xf4),    // text
    base: RgbColor::new(0x1e, 0x1e, 0x2e),           // base
    alternate_base: RgbColor::new(0x31, 0x32, 0x44), // surface0
    text: RgbColor::new(0xcd, 0xd6, 0xf4),
    button: RgbColor::new(0x18, 0x18, 0x25),
    button_text: RgbColor::new(0xcd, 0xd6, 0xf4),
    tooltip_base: RgbColor::new(0x18, 0x18, 0x25),
    tooltip_text: RgbColor::new(0xcd, 0xd6, 0xf4),
    light: RgbColor::new(0x58, 0x5b, 0x70), // surface2
};

const CATPPUCCIN_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "catppuccin-latte",
        name: "Latte",
        preset: CATPPUCCIN_LATTE,
        default_accent: RgbColor::new(0x88, 0x39, 0xef), // mauve
    },
    VariantInfo {
        id: "catppuccin-frappe",
        name: "Frappé",
        preset: CATPPUCCIN_FRAPPE,
        default_accent: RgbColor::new(0xca, 0x9e, 0xe6), // mauve
    },
    VariantInfo {
        id: "catppuccin-macchiato",
        name: "Macchiato",
        preset: CATPPUCCIN_MACCHIATO,
        default_accent: RgbColor::new(0xc6, 0xa0, 0xf6), // mauve
    },
    VariantInfo {
        id: "catppuccin-mocha",
        name: "Mocha",
        preset: CATPPUCCIN_MOCHA,
        default_accent: RgbColor::new(0xcb, 0xa6, 0xf7), // mauve
    },
];

// Source: stephango.com/flexoki (official site). Only one background shade
// is published per mode (`paper`/`bg`), so `window`/`alternate_base` reuse
// `base` rather than guessing a second one. Default accent is Blue (the
// "600" light-mode / "400" dark-mode value from Flexoki's accent table).
const FLEXOKI_LIGHT: PalettePreset = PalettePreset {
    window: RgbColor::new(0xff, 0xfc, 0xf0),         // paper
    window_text: RgbColor::new(0x10, 0x0f, 0x0f),    // tx
    base: RgbColor::new(0xff, 0xfc, 0xf0),           // paper
    alternate_base: RgbColor::new(0xff, 0xfc, 0xf0), // paper
    text: RgbColor::new(0x10, 0x0f, 0x0f),
    button: RgbColor::new(0xff, 0xfc, 0xf0),
    button_text: RgbColor::new(0x10, 0x0f, 0x0f),
    tooltip_base: RgbColor::new(0xff, 0xfc, 0xf0),
    tooltip_text: RgbColor::new(0x10, 0x0f, 0x0f),
    light: RgbColor::new(0xff, 0xff, 0xff),
};

const FLEXOKI_DARK: PalettePreset = PalettePreset {
    window: RgbColor::new(0x10, 0x0f, 0x0f),         // bg
    window_text: RgbColor::new(0xf2, 0xf0, 0xe5),    // tx
    base: RgbColor::new(0x10, 0x0f, 0x0f),           // bg
    alternate_base: RgbColor::new(0x10, 0x0f, 0x0f), // bg
    text: RgbColor::new(0xf2, 0xf0, 0xe5),
    button: RgbColor::new(0x10, 0x0f, 0x0f),
    button_text: RgbColor::new(0xf2, 0xf0, 0xe5),
    tooltip_base: RgbColor::new(0x10, 0x0f, 0x0f),
    tooltip_text: RgbColor::new(0xf2, 0xf0, 0xe5),
    light: RgbColor::new(0xb7, 0xb5, 0xac), // tx-2
};

const FLEXOKI_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "flexoki-light",
        name: "ライト",
        preset: FLEXOKI_LIGHT,
        default_accent: RgbColor::new(0x20, 0x5e, 0xa6), // blue-600
    },
    VariantInfo {
        id: "flexoki-dark",
        name: "ダーク",
        preset: FLEXOKI_DARK,
        default_accent: RgbColor::new(0x43, 0x85, 0xbe), // blue-400
    },
];

pub const SCHEMES: &[SchemeInfo] = &[
    SchemeInfo {
        id: "ayame",
        name: "Ayame",
        variants: AYAME_VARIANTS,
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
    fn ayame_variants_still_use_the_original_presets() {
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
