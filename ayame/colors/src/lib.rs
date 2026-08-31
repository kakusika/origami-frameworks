//! Ayame's own QPalette color data, decoupled from `crates/qml6/cpp/theme_palette.cpp`.
//!
//! This crate owns two things: the fixed light/dark palette presets (the
//! colors that used to be hardcoded `QColor` literals in C++), and the
//! logic to compose a preset with a user-chosen accent color into the full
//! set of `QPalette` roles `theme_palette.cpp` applies. It has no build.rs
//! and registers no QML type -- it is pure data/logic, consumed by
//! `crates/qml6` which owns the actual FFI boundary into Qt.
//!
//! `presets` extends this with a registry of named color schemes
//! (TokyoNight, Catppuccin, Flexoki, alongside Ayame's own light/dark)
//! layered on top of the same `PalettePreset`/`RgbColor` types.

pub mod presets;

/// An 8-bit-per-channel RGB color, independent of any Qt type so this crate
/// has no cxx-qt bridge/build.rs of its own.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RgbColor {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl RgbColor {
    pub const fn new(r: u8, g: u8, b: u8) -> Self {
        Self { r, g, b }
    }

    pub fn to_hex(self) -> String {
        format!("#{:02x}{:02x}{:02x}", self.r, self.g, self.b)
    }

    pub fn from_hex(s: &str) -> Option<Self> {
        let s = s.strip_prefix('#').unwrap_or(s);
        if s.len() != 6 {
            return None;
        }
        let r = u8::from_str_radix(&s[0..2], 16).ok()?;
        let g = u8::from_str_radix(&s[2..4], 16).ok()?;
        let b = u8::from_str_radix(&s[4..6], 16).ok()?;
        Some(Self { r, g, b })
    }

    /// Packed `0xRRGGBB`, matching Qt's `QRgb` typedef -- this is the shape
    /// `theme_palette.cpp`'s FFI boundary expects (see
    /// `cettila_apply_theme_palette`), since passing `cxx_qt_lib::QColor`
    /// itself across the plain `extern "C"` boundary has no precedent in
    /// this codebase.
    pub fn to_rgb_u32(self) -> u32 {
        ((self.r as u32) << 16) | ((self.g as u32) << 8) | self.b as u32
    }
}

/// The QPalette roles that make up a base preset. `Highlight` and
/// `HighlightedText` are deliberately excluded -- they're derived from the
/// user's freely-chosen accent color instead (see `compose_palette`), not
/// baked into the preset itself.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PalettePreset {
    pub window: RgbColor,
    pub window_text: RgbColor,
    pub base: RgbColor,
    pub alternate_base: RgbColor,
    pub text: RgbColor,
    pub button: RgbColor,
    pub button_text: RgbColor,
    pub tooltip_base: RgbColor,
    pub tooltip_text: RgbColor,
    pub light: RgbColor,
}

/// Ayame Iris Light Preset (Clean White & Soft Lavender White base with dark violet text).
pub const LIGHT_PRESET: PalettePreset = PalettePreset {
    window: RgbColor::new(0xf0, 0xf1, 0xf8),
    window_text: RgbColor::new(0x1a, 0x1b, 0x2d),
    base: RgbColor::new(0xfa, 0xfa, 0xff),
    alternate_base: RgbColor::new(0xe6, 0xe8, 0xf4),
    text: RgbColor::new(0x1a, 0x1b, 0x2d),
    button: RgbColor::new(0xf0, 0xf1, 0xf8),
    button_text: RgbColor::new(0x1a, 0x1b, 0x2d),
    tooltip_base: RgbColor::new(0xff, 0xff, 0xff),
    tooltip_text: RgbColor::new(0x1a, 0x1b, 0x2d),
    light: RgbColor::new(0xff, 0xff, 0xff),
};

/// Ayame Iris Dark Preset (Deep Blue-Violet dark base with crisp white text).
pub const DARK_PRESET: PalettePreset = PalettePreset {
    window: RgbColor::new(0x22, 0x22, 0x30),
    window_text: RgbColor::new(0xf1, 0xf3, 0xf9),
    base: RgbColor::new(0x1a, 0x1a, 0x24),
    alternate_base: RgbColor::new(0x2a, 0x2a, 0x3c),
    text: RgbColor::new(0xf1, 0xf3, 0xf9),
    button: RgbColor::new(0x22, 0x22, 0x30),
    button_text: RgbColor::new(0xf1, 0xf3, 0xf9),
    tooltip_base: RgbColor::new(0x22, 0x22, 0x30),
    tooltip_text: RgbColor::new(0xf1, 0xf3, 0xf9),
    light: RgbColor::new(0x35, 0x35, 0x4c),
};

/// Ayame's signature Iris Blue-Violet accent color.
pub const DEFAULT_ACCENT: RgbColor = RgbColor::new(0x6e, 0x62, 0xe4);

/// Selects a preset by the same flat id `theme_mode`/`ThemeSettings`
/// persist (e.g. `"dark"`, `"catppuccin-mocha"`) -- see `presets::SCHEMES`
/// for the full registry. Ayame's own two variants keep the bare ids
/// `"light"`/`"dark"` for backward compatibility with already-saved
/// `settings.yaml` files that predate every other scheme; every other
/// scheme's ids are `"<scheme>-<variant>"` to avoid colliding with them
/// (e.g. Flexoki's light variant is `"flexoki-light"`, not `"light"`).
/// Unknown ids fall back to the light preset (callers are expected to gate
/// out `"system"` before reaching here -- see `apply_theme`'s early
/// return).
pub fn preset_by_id(id: &str) -> PalettePreset {
    presets::find_variant(id)
        .map(|variant| variant.preset)
        .unwrap_or(LIGHT_PRESET)
}

/// The given variant's own "signature" accent color, shown as the default
/// in Cettila's accent color picker when this scheme/variant is selected
/// (still freely overridable by the user afterwards). Falls back to
/// `DEFAULT_ACCENT` for unknown ids.
pub fn default_accent_for(id: &str) -> RgbColor {
    presets::find_variant(id)
        .map(|variant| variant.default_accent)
        .unwrap_or(DEFAULT_ACCENT)
}

/// Which scheme a flat variant id belongs to (e.g. `"catppuccin-mocha"` ->
/// `Some("catppuccin")`, `"dark"` -> `Some("ayame")`), or `None` if `id`
/// doesn't match any known variant (including `"system"`, which isn't a
/// scheme at all).
pub fn scheme_of(id: &str) -> Option<&'static str> {
    presets::scheme_of(id)
}

/// All twelve `QPalette` roles `theme_palette.cpp` applies, after composing
/// a preset with a chosen accent color.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ComposedPalette {
    pub window: RgbColor,
    pub window_text: RgbColor,
    pub base: RgbColor,
    pub alternate_base: RgbColor,
    pub text: RgbColor,
    pub button: RgbColor,
    pub button_text: RgbColor,
    pub highlight: RgbColor,
    pub highlighted_text: RgbColor,
    pub tooltip_base: RgbColor,
    pub tooltip_text: RgbColor,
    pub light: RgbColor,
}

/// Reused rather than inventing new literals: `LIGHT_PRESET.window_text`.
const NEAR_BLACK: RgbColor = RgbColor::new(0x1a, 0x1b, 0x2d);
/// Reused rather than inventing new literals: `DARK_PRESET.text`.
const NEAR_WHITE: RgbColor = RgbColor::new(0xf1, 0xf3, 0xf9);

/// Perceptual luminance (0..255, ITU BT.601 weights) above which black text
/// reads better than white on a solid fill of this color. 150 is chosen
/// (rather than the naive midpoint 128) because it reproduces the existing
/// hardcoded behavior for `DEFAULT_ACCENT` (luminance ~147 -> white text,
/// matching both former presets' `HighlightedText`).
const CONTRAST_LUMINANCE_THRESHOLD: f32 = 150.0;

fn contrasting_text_color(accent: RgbColor) -> RgbColor {
    let luminance = 0.299 * accent.r as f32 + 0.587 * accent.g as f32 + 0.114 * accent.b as f32;
    if luminance > CONTRAST_LUMINANCE_THRESHOLD {
        NEAR_BLACK
    } else {
        NEAR_WHITE
    }
}

/// Composes a base preset with a freely-chosen accent color into the full
/// set of roles `theme_palette.cpp` needs. `Highlight` becomes the accent
/// as-is; `HighlightedText` is derived for contrast rather than kept as a
/// fixed literal, since a fixed literal can't stay legible against an
/// arbitrary user-chosen accent.
pub fn compose_palette(preset: PalettePreset, accent: RgbColor) -> ComposedPalette {
    ComposedPalette {
        window: preset.window,
        window_text: preset.window_text,
        base: preset.base,
        alternate_base: preset.alternate_base,
        text: preset.text,
        button: preset.button,
        button_text: preset.button_text,
        highlight: accent,
        highlighted_text: contrasting_text_color(accent),
        tooltip_base: preset.tooltip_base,
        tooltip_text: preset.tooltip_text,
        light: preset.light,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_round_trips() {
        let color = RgbColor::new(0x6e, 0x62, 0xe4);
        assert_eq!(color.to_hex(), "#6e62e4");
        assert_eq!(RgbColor::from_hex("#6e62e4"), Some(color));
        assert_eq!(RgbColor::from_hex("6e62e4"), Some(color));
    }

    #[test]
    fn from_hex_rejects_malformed_input() {
        assert_eq!(RgbColor::from_hex("#6e62e"), None);
        assert_eq!(RgbColor::from_hex("#6e62e4ff"), None);
        assert_eq!(RgbColor::from_hex("#gggggg"), None);
    }

    #[test]
    fn to_rgb_u32_matches_qrgb_packing() {
        assert_eq!(RgbColor::new(0x6e, 0x62, 0xe4).to_rgb_u32(), 0x006e_62e4);
    }

    #[test]
    fn default_accent_reproduces_historical_highlighted_text_choice() {
        let light = compose_palette(LIGHT_PRESET, DEFAULT_ACCENT);
        let dark = compose_palette(DARK_PRESET, DEFAULT_ACCENT);
        assert_eq!(light.highlight, DEFAULT_ACCENT);
        assert_eq!(dark.highlight, DEFAULT_ACCENT);
        assert_eq!(light.highlighted_text, NEAR_WHITE);
        assert_eq!(dark.highlighted_text, NEAR_WHITE);
    }

    #[test]
    fn contrast_picks_black_text_on_bright_accent() {
        let bright_yellow = RgbColor::new(0xff, 0xff, 0x00);
        assert_eq!(contrasting_text_color(bright_yellow), NEAR_BLACK);
    }

    #[test]
    fn contrast_picks_white_text_on_dark_accent() {
        let dark_purple = RgbColor::new(0x30, 0x10, 0x40);
        assert_eq!(contrasting_text_color(dark_purple), NEAR_WHITE);
    }

    #[test]
    fn preset_by_id_falls_back_to_light() {
        assert_eq!(preset_by_id("dark"), DARK_PRESET);
        assert_eq!(preset_by_id("light"), LIGHT_PRESET);
        assert_eq!(preset_by_id("system"), LIGHT_PRESET);
        assert_eq!(preset_by_id("anything-else"), LIGHT_PRESET);
    }

    #[test]
    fn preset_by_id_resolves_named_schemes() {
        assert_eq!(
            preset_by_id("catppuccin-mocha"),
            presets::find_variant("catppuccin-mocha").unwrap().preset
        );
        assert_eq!(
            preset_by_id("tokyonight-storm"),
            presets::find_variant("tokyonight-storm").unwrap().preset
        );
        assert_eq!(
            preset_by_id("flexoki-light"),
            presets::find_variant("flexoki-light").unwrap().preset
        );
    }

    #[test]
    fn default_accent_for_known_and_unknown_ids() {
        assert_eq!(default_accent_for("dark"), DEFAULT_ACCENT);
        assert_eq!(
            default_accent_for("catppuccin-mocha"),
            RgbColor::new(0xcb, 0xa6, 0xf7)
        );
        assert_eq!(default_accent_for("nonexistent"), DEFAULT_ACCENT);
    }

    #[test]
    fn scheme_of_known_and_unknown_ids() {
        assert_eq!(scheme_of("light"), Some("ayame"));
        assert_eq!(scheme_of("catppuccin-latte"), Some("catppuccin"));
        assert_eq!(scheme_of("flexoki-dark"), Some("flexoki"));
        assert_eq!(scheme_of("system"), None);
        assert_eq!(scheme_of("nonexistent"), None);
    }
}
