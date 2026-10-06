use crate::palette::{PalettePreset, RgbColor};

use super::VariantInfo;

// Source: github.com/folke/tokyonight.nvim, `lua/tokyonight/colors/storm.lua`
// and `colors/night.lua` (bg/bg_dark/bg_highlight/fg/fg_dark/blue), and the
// project's own exported `extras/alacritty/tokyonight_day.toml` for Day
// (its Lua source computes Day by inverting Night at runtime, so the
// maintained Alacritty export is the only fixed-literal source available).
// Night only overrides `bg`/`bg_dark` on top of Storm in the upstream Lua,
// so its other roles below are Storm's values, not independently sourced.
pub const TOKYONIGHT_STORM: PalettePreset = PalettePreset {
    window: RgbColor::new(0x1f, 0x23, 0x35),         // bg_dark
    window_text: RgbColor::new(0xc0, 0xca, 0xf5),    // fg
    base: RgbColor::new(0x24, 0x28, 0x3b),           // bg
    alternate_base: RgbColor::new(0x29, 0x2e, 0x42), // bg_highlight
    text: RgbColor::new(0xc0, 0xca, 0xf5),           // fg
    button: RgbColor::new(0x1f, 0x23, 0x35),         // bg_dark
    button_text: RgbColor::new(0xc0, 0xca, 0xf5),    // fg
    tooltip_base: RgbColor::new(0x1f, 0x23, 0x35),   // bg_dark
    tooltip_text: RgbColor::new(0xc0, 0xca, 0xf5),   // fg
    light: RgbColor::new(0x3b, 0x42, 0x61), // fg_gutter (one step above bg_highlight; fg_dark is a text color)
};

pub const TOKYONIGHT_NIGHT: PalettePreset = PalettePreset {
    window: RgbColor::new(0x16, 0x16, 0x1e),       // bg_dark
    base: RgbColor::new(0x1a, 0x1b, 0x26),         // bg
    button: RgbColor::new(0x16, 0x16, 0x1e),       // bg_dark
    tooltip_base: RgbColor::new(0x16, 0x16, 0x1e), // bg_dark
    ..TOKYONIGHT_STORM
};

pub const TOKYONIGHT_DAY: PalettePreset = PalettePreset {
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

pub const TOKYONIGHT_VARIANTS: &[VariantInfo] = &[
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
