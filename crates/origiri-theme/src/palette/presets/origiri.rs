use crate::palette::{DARK_PRESET, DEFAULT_ACCENT, LIGHT_PRESET};

use super::VariantInfo;

pub const ORIGIRI_VARIANTS: &[VariantInfo] = &[
    VariantInfo {
        id: "light",
        name: "ライト",
        preset: LIGHT_PRESET,
        default_accent: DEFAULT_ACCENT,
    },
    VariantInfo {
        id: "dark",
        name: "ダーク",
        preset: DARK_PRESET,
        default_accent: DEFAULT_ACCENT,
    },
];
