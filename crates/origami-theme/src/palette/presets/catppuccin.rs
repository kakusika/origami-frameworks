use crate::palette::{PalettePreset, RgbColor};

use super::VariantInfo;

// Source: github.com/catppuccin/catppuccin's own README palette table
// (Base/Mantle/Text/Surface0/Surface2 per flavor). Default accent is Mauve
// in every flavor -- the color most associated with Catppuccin's own
// branding.
pub const CATPPUCCIN_LATTE: PalettePreset = PalettePreset {
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

pub const CATPPUCCIN_FRAPPE: PalettePreset = PalettePreset {
    window: RgbColor::new(0x29, 0x2c, 0x3c),         // mantle
    window_text: RgbColor::new(0xc6, 0xd0, 0xf5),    // text
    base: RgbColor::new(0x30, 0x34, 0x46),           // base
    alternate_base: RgbColor::new(0x41, 0x45, 0x59), // surface0
    text: RgbColor::new(0xc6, 0xd0, 0xf5),
    button: RgbColor::new(0x29, 0x2c, 0x3c),
    button_text: RgbColor::new(0xc6, 0xd0, 0xf5),
    tooltip_base: RgbColor::new(0x29, 0x2c, 0x3c),
    tooltip_text: RgbColor::new(0xc6, 0xd0, 0xf5),
    light: RgbColor::new(0x51, 0x57, 0x6d), // surface1
};

pub const CATPPUCCIN_MACCHIATO: PalettePreset = PalettePreset {
    window: RgbColor::new(0x1e, 0x20, 0x30),         // mantle
    window_text: RgbColor::new(0xca, 0xd3, 0xf5),    // text
    base: RgbColor::new(0x24, 0x27, 0x3a),           // base
    alternate_base: RgbColor::new(0x36, 0x3a, 0x4f), // surface0
    text: RgbColor::new(0xca, 0xd3, 0xf5),
    button: RgbColor::new(0x1e, 0x20, 0x30),
    button_text: RgbColor::new(0xca, 0xd3, 0xf5),
    tooltip_base: RgbColor::new(0x1e, 0x20, 0x30),
    tooltip_text: RgbColor::new(0xca, 0xd3, 0xf5),
    light: RgbColor::new(0x49, 0x4d, 0x64), // surface1
};

pub const CATPPUCCIN_MOCHA: PalettePreset = PalettePreset {
    window: RgbColor::new(0x18, 0x18, 0x25),         // mantle
    window_text: RgbColor::new(0xcd, 0xd6, 0xf4),    // text
    base: RgbColor::new(0x1e, 0x1e, 0x2e),           // base
    alternate_base: RgbColor::new(0x31, 0x32, 0x44), // surface0
    text: RgbColor::new(0xcd, 0xd6, 0xf4),
    button: RgbColor::new(0x18, 0x18, 0x25),
    button_text: RgbColor::new(0xcd, 0xd6, 0xf4),
    tooltip_base: RgbColor::new(0x18, 0x18, 0x25),
    tooltip_text: RgbColor::new(0xcd, 0xd6, 0xf4),
    light: RgbColor::new(0x45, 0x47, 0x5a), // surface1
};

pub const CATPPUCCIN_VARIANTS: &[VariantInfo] = &[
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
