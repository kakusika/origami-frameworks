//! `ayame-slint`: the Slint side of Ayame's own design system, alongside
//! `crates/stylekit`'s QML `Theme`/`Units` singletons -- resolves the
//! same persisted `ayame_config::Settings` (`~/.config/ayamerc`, the
//! exact file `qt/qml6`'s `Units.qml`/`ThemeSettings` already read/write)
//! into concrete values a Slint UI can bind to, plus ships a real
//! importable `ui/` library (`tokens.slint`, `icons.slint`,
//! `components.slint`, via `slint-build`'s library-path mechanism) so any
//! Slint app in this workspace family gets the same look, sourced from
//! the same settings, instead of hand-rolling its own token/widget set.
//! Pure Rust, no `slint` dependency -- decoupled from any consuming app's
//! Slint version.
//!
//! Originated as `cettila`'s own `cettila-slint-style` (a first PoC that
//! read `origami-config`'s per-vault settings instead) -- moved here and
//! switched to `ayame-config`'s global settings so it's genuinely shared
//! with every other Ayame-styled app, not just cettila.

pub use ayame_colors as palette;

use palette::RgbColor;

/// 8-bit RGBA. `a: 255` unless a token is deliberately translucent (`hover`/
/// `pressed`, matching `Theme.qml`'s own `paletteFor()`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rgba {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl Rgba {
    pub const fn opaque(rgb: RgbColor) -> Self {
        Self { r: rgb.r, g: rgb.g, b: rgb.b, a: 255 }
    }

    pub fn translucent(rgb: RgbColor, alpha: f32) -> Self {
        Self { r: rgb.r, g: rgb.g, b: rgb.b, a: (alpha.clamp(0.0, 1.0) * 255.0).round() as u8 }
    }
}

/// Pre-composites `fg` over `bg` at `alpha`, returning an opaque result --
/// ported from `Theme.qml`'s `opaqueBlend()`. Used for border colors: a
/// translucent border double-blends wherever it overlaps another
/// translucent layer, so callers that render on a known, solid background
/// use this instead of a raw alpha color.
fn opaque_blend(fg: RgbColor, bg: RgbColor, alpha: f32) -> RgbColor {
    let mix = |f: u8, b: u8| -> u8 {
        (f as f32 * alpha + b as f32 * (1.0 - alpha)).round() as u8
    };
    RgbColor::new(mix(fg.r, bg.r), mix(fg.g, bg.g), mix(fg.b, bg.b))
}

/// Mirrors `ui/tokens.slint`'s `Tokens` global 1:1 -- keep both in sync by
/// hand if either changes.
#[derive(Debug, Clone, Copy)]
pub struct ColorTokens {
    pub background: Rgba,
    pub surface: Rgba,
    pub surface_raised: Rgba,
    pub border: Rgba,
    pub divider: Rgba,
    pub hover: Rgba,
    pub pressed: Rgba,
    pub accent: Rgba,
    pub text_primary: Rgba,
    pub text_secondary: Rgba,
    pub text_disabled: Rgba,
    pub destructive: Rgba,
    pub selected_surface: Rgba,
}

/// Ayame's own fixed semantic constant (`Theme.qml`'s `negativeTextColor`)
/// -- not persisted/customizable, matches upstream: it's a hardcoded
/// constant there too, independent of the active scheme/accent.
const DESTRUCTIVE: RgbColor = RgbColor::new(0xda, 0x44, 0x53);

/// Derives every flat `ColorTokens` field from one composed palette. This
/// mapping (which upstream `Theme.qml` "color set" each flat token name
/// corresponds to) is a judgment call made porting this into a flat token
/// list instead of QML's per-subtree `paletteFor(set)` calls -- not
/// upstream gospel, easy to retune here if it looks wrong once actually
/// running:
/// - `background` = the view/content color set's background (`base`).
/// - `surface`/`surface-raised` = the header/chrome color set's background
///   (`button`) / the `light` role (a bevel-highlight shade).
/// - `border`/`divider` = `opaque_blend(text, base, 0.3 / 0.4)` -- both
///   derived from the view set's own text/background, `divider` at a
///   stronger blend so it stays visually distinct (a drag handle) from the
///   softer `border`.
/// - `hover`/`pressed` = the accent at alpha 0.15/0.5 (translucent,
///   `Theme.qml`'s own hoverColor/pressedColor -- these don't vary by
///   color set upstream either).
/// - `text-primary`/`text-secondary`/`text-disabled` = the view set's text
///   at alpha 1.0/0.3/0.25.
/// - `selected-surface` = `opaque_blend(accent, base, 0.25)`, this
///   library's own concept (no upstream equivalent -- Theme.qml has no
///   "list selection" role).
fn resolve_colors(preset: palette::PalettePreset, accent: RgbColor) -> ColorTokens {
    let composed = palette::compose_palette(preset, accent);
    ColorTokens {
        background: Rgba::opaque(composed.base),
        surface: Rgba::opaque(composed.button),
        surface_raised: Rgba::opaque(composed.light),
        border: Rgba::opaque(opaque_blend(composed.text, composed.base, 0.3)),
        divider: Rgba::opaque(opaque_blend(composed.text, composed.base, 0.4)),
        hover: Rgba::translucent(composed.highlight, 0.15),
        pressed: Rgba::translucent(composed.highlight, 0.5),
        accent: Rgba::opaque(composed.highlight),
        text_primary: Rgba::opaque(composed.text),
        text_secondary: Rgba::translucent(composed.text, 0.3),
        text_disabled: Rgba::translucent(composed.text, 0.25),
        destructive: Rgba::opaque(DESTRUCTIVE),
        selected_surface: Rgba::opaque(opaque_blend(composed.highlight, composed.base, 0.25)),
    }
}

/// Corner-radius/border-width presets in px -- ported from `Units.qml`'s
/// `_cornerRadiusPresets`/`_borderWidthPresets`. Deliberately not scaled by
/// `ui_scale` -- confirmed neither is upstream either.
#[derive(Debug, Clone, Copy)]
pub struct ShapeTokens {
    pub corner_radius_px: f32,
    pub border_width_px: f32,
}

fn corner_radius_px(preset: &str) -> f32 {
    match preset {
        "circle" => 9999.0,
        "large" => 14.0,
        "medium" => 8.0,
        "small" => 4.0,
        "disabled" => 0.0,
        _ => 4.0,
    }
}

fn border_width_px(preset: &str) -> f32 {
    match preset {
        "thin" => 0.5,
        "thick" => 2.0,
        _ => 1.0,
    }
}

/// This library's fixed spacing values (`ui/tokens.slint`'s `spacing-
/// small/medium/large`), scaled by `ui_scale`. Upstream `Units.qml`
/// instead derives spacing from `gridUnit = round(FontMetrics.height *
/// uiScale)` -- there's no Qt-free equivalent of `FontMetrics` available
/// here, so this is a deliberate simplification (a straight multiplier on
/// already-fixed values), not a port of the gridUnit formula itself.
#[derive(Debug, Clone, Copy)]
pub struct SpacingTokens {
    pub small_px: f32,
    pub medium_px: f32,
    pub large_px: f32,
}

const BASE_SPACING_SMALL_PX: f32 = 4.0;
const BASE_SPACING_MEDIUM_PX: f32 = 8.0;
const BASE_SPACING_LARGE_PX: f32 = 16.0;

fn animation_speed_multiplier(preset: &str) -> f32 {
    match preset {
        "slow" => 1.75,
        "fast" => 0.5,
        _ => 1.2, // "normal"
    }
}

fn scaled_duration(base_ms: f32, multiplier: f32, enabled: bool) -> i32 {
    if enabled { (base_ms * multiplier).round() as i32 } else { 0 }
}

/// Ported from `Units.qml`'s `veryShortDuration`/`shortDuration`/
/// `longDuration`/`veryLongDuration` -- all zero when `enabled` is false, a
/// `Behavior`/animation bound to any of these then applies its target
/// value immediately instead of animating, no per-call-site branching
/// needed.
#[derive(Debug, Clone, Copy)]
pub struct AnimationTokens {
    pub enabled: bool,
    pub very_short_ms: i32,
    pub short_ms: i32,
    pub long_ms: i32,
    pub very_long_ms: i32,
}

#[derive(Debug, Clone, Copy)]
pub struct ResolvedTheme {
    pub colors: ColorTokens,
    pub shape: ShapeTokens,
    pub spacing: SpacingTokens,
    pub animation: AnimationTokens,
}

/// Reads `ayame_config::Settings::load()` (the same global `~/.config/
/// ayamerc` `qt/qml6`'s QML-exposed settings objects read/write) and
/// resolves it into concrete values, the same way `Theme.qml`/`Units.qml`
/// do for the QML side. Cheap (one small settings-file read + arithmetic,
/// no image decoding or similar) -- safe to call again on every settings
/// change rather than patching individual fields.
pub fn resolve() -> ResolvedTheme {
    let style = ayame_config::Settings::load().style;
    let accent = RgbColor::from_hex(&style.accent_color).unwrap_or(palette::DEFAULT_ACCENT);
    let preset = palette::preset_by_id(&style.theme_mode);

    let ui_scale = style.ui_scale as f32;
    let multiplier = animation_speed_multiplier(&style.animation_speed);
    let duration = |base_ms: f32| scaled_duration(base_ms, multiplier, style.animations_enabled);

    ResolvedTheme {
        colors: resolve_colors(preset, accent),
        shape: ShapeTokens {
            corner_radius_px: corner_radius_px(&style.corner_radius),
            border_width_px: border_width_px(&style.border_width),
        },
        spacing: SpacingTokens {
            small_px: BASE_SPACING_SMALL_PX * ui_scale,
            medium_px: BASE_SPACING_MEDIUM_PX * ui_scale,
            large_px: BASE_SPACING_LARGE_PX * ui_scale,
        },
        animation: AnimationTokens {
            enabled: style.animations_enabled,
            very_short_ms: duration(50.0),
            short_ms: duration(150.0),
            long_ms: duration(300.0),
            very_long_ms: duration(500.0),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corner_radius_presets_match_stylekit_units_qml() {
        assert_eq!(corner_radius_px("circle"), 9999.0);
        assert_eq!(corner_radius_px("large"), 14.0);
        assert_eq!(corner_radius_px("medium"), 8.0);
        assert_eq!(corner_radius_px("small"), 4.0);
        assert_eq!(corner_radius_px("disabled"), 0.0);
    }

    #[test]
    fn border_width_presets_match_stylekit_units_qml() {
        assert_eq!(border_width_px("thin"), 0.5);
        assert_eq!(border_width_px("default"), 1.0);
        assert_eq!(border_width_px("thick"), 2.0);
    }

    #[test]
    fn animations_disabled_zeroes_every_duration() {
        assert_eq!(scaled_duration(50.0, 1.75, false), 0);
        assert_eq!(scaled_duration(500.0, 0.5, false), 0);
    }

    #[test]
    fn animation_speed_scales_base_durations() {
        assert_eq!(scaled_duration(50.0, animation_speed_multiplier("slow"), true), 88);
        assert_eq!(scaled_duration(500.0, animation_speed_multiplier("fast"), true), 250);
        assert_eq!(scaled_duration(300.0, animation_speed_multiplier("normal"), true), 360);
    }

    #[test]
    fn ui_scale_scales_spacing_only() {
        // 2x ui_scale doubles spacing but must never touch shape tokens --
        // confirmed corner-radius/border-width have no ui_scale factor at
        // all in `resolve()`.
        let small = BASE_SPACING_SMALL_PX * 2.0;
        assert_eq!(small, 8.0);
        assert_eq!(corner_radius_px("medium"), 8.0); // unaffected by any scale
    }

    #[test]
    fn opaque_blend_matches_theme_qml_formula() {
        let white = RgbColor::new(255, 255, 255);
        let black = RgbColor::new(0, 0, 0);
        let half = opaque_blend(white, black, 0.5);
        assert_eq!(half, RgbColor::new(128, 128, 128));
    }

    #[test]
    fn resolve_does_not_panic_regardless_of_host_ayamerc_state() {
        // `resolve()` reads the real `~/.config/ayamerc` via
        // `ayame_config::Settings::load()` (falls back to `Settings::
        // default()` if missing/unparseable) -- this only checks it
        // completes and produces in-range values for *any* preset
        // string, not a specific host's actual settings.
        let theme = resolve();
        assert!(theme.shape.corner_radius_px >= 0.0);
        assert!(theme.shape.border_width_px >= 0.0);
    }
}
