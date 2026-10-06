use crate::palette::{PalettePreset, RgbColor};

use super::VariantInfo;

// Source: Blender default theme (Blender 4.x / 5.x `userdef_default_theme.c` & `Blender_Dark.xml` / `Blender_Light.xml`)
// base = editor/properties background (#303030), window = gutter/dark background (#1d1d1d),
// button = panel/widget surface (#3d3d3d), alternate_base = inset fields (#222222),
// text = #e6e6e6, light = elevated button (#545454).
// Default accent is Blender Blue (#4772b3).
pub const BLENDER_DARK: PalettePreset = PalettePreset {
    window: RgbColor::new(0x1d, 0x1d, 0x1d),
    window_text: RgbColor::new(0xe6, 0xe6, 0xe6),
    base: RgbColor::new(0x30, 0x30, 0x30),
    alternate_base: RgbColor::new(0x22, 0x22, 0x22),
    text: RgbColor::new(0xe6, 0xe6, 0xe6),
    button: RgbColor::new(0x3d, 0x3d, 0x3d),
    button_text: RgbColor::new(0xe6, 0xe6, 0xe6),
    tooltip_base: RgbColor::new(0x1d, 0x1d, 0x1d),
    tooltip_text: RgbColor::new(0xd9, 0xd9, 0xd9),
    light: RgbColor::new(0x54, 0x54, 0x54),
};

pub const BLENDER_LIGHT: PalettePreset = PalettePreset {
    window: RgbColor::new(0xe6, 0xe6, 0xe6),
    window_text: RgbColor::new(0x1a, 0x1a, 0x1a),
    base: RgbColor::new(0xcc, 0xcc, 0xcc),
    alternate_base: RgbColor::new(0xb3, 0xb3, 0xb3),
    text: RgbColor::new(0x1a, 0x1a, 0x1a),
    button: RgbColor::new(0xdb, 0xdb, 0xdb),
    button_text: RgbColor::new(0x1a, 0x1a, 0x1a),
    tooltip_base: RgbColor::new(0xdb, 0xdb, 0xdb),
    tooltip_text: RgbColor::new(0x1a, 0x1a, 0x1a),
    light: RgbColor::new(0xff, 0xff, 0xff),
};

pub const BLENDER_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "blender-dark",
        name: "ダーク",
        preset: BLENDER_DARK,
        default_accent: RgbColor::new(0x47, 0x72, 0xb3), // Blender Blue
    },
    VariantInfo {
        id: "blender-light",
        name: "ライト",
        preset: BLENDER_LIGHT,
        default_accent: RgbColor::new(0x56, 0x80, 0xc2), // Blender Blue Light
    },
];
