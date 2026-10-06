use crate::palette::{PalettePreset, RgbColor};

use super::VariantInfo;

// Source: stephango.com/flexoki (official site): `paper`/`bg` for the content,
// `bg-2` for the chrome, `ui` for the raised shade; `window`/`alternate_base`
// reuse `base`. Default accent is Blue (the
// "600" light-mode / "400" dark-mode value from Flexoki's accent table).
pub const FLEXOKI_LIGHT: PalettePreset = PalettePreset {
    window: RgbColor::new(0xff, 0xfc, 0xf0),         // paper
    window_text: RgbColor::new(0x10, 0x0f, 0x0f),    // tx
    base: RgbColor::new(0xff, 0xfc, 0xf0),           // paper
    alternate_base: RgbColor::new(0xff, 0xfc, 0xf0), // paper
    text: RgbColor::new(0x10, 0x0f, 0x0f),
    button: RgbColor::new(0xf2, 0xf0, 0xe5), // bg-2
    button_text: RgbColor::new(0x10, 0x0f, 0x0f),
    tooltip_base: RgbColor::new(0xf2, 0xf0, 0xe5), // bg-2
    tooltip_text: RgbColor::new(0x10, 0x0f, 0x0f),
    light: RgbColor::new(0xff, 0xff, 0xff),
};

pub const FLEXOKI_DARK: PalettePreset = PalettePreset {
    window: RgbColor::new(0x10, 0x0f, 0x0f),         // bg
    window_text: RgbColor::new(0xf2, 0xf0, 0xe5),    // tx
    base: RgbColor::new(0x10, 0x0f, 0x0f),           // bg
    alternate_base: RgbColor::new(0x10, 0x0f, 0x0f), // bg
    text: RgbColor::new(0xf2, 0xf0, 0xe5),
    button: RgbColor::new(0x1c, 0x1b, 0x1a), // bg-2
    button_text: RgbColor::new(0xf2, 0xf0, 0xe5),
    tooltip_base: RgbColor::new(0x1c, 0x1b, 0x1a), // bg-2
    tooltip_text: RgbColor::new(0xf2, 0xf0, 0xe5),
    light: RgbColor::new(0x28, 0x27, 0x26), // ui (tx-2 is a text color)
};

pub const FLEXOKI_VARIANTS: &[VariantInfo] = &[
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
