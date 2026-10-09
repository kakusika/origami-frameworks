//! Resolves a [`ThemeSettings`] into concrete design tokens (colors, shape,
//! spacing, animation durations). The values mirror `ui/tokens.slint`'s
//! `Tokens` global in `origami-slint` 1:1 -- keep both in sync by hand if
//! either changes.

use crate::palette::{self, RgbColor, contrast_ratio};
use crate::settings::{AnimationSpeed, BorderWidth, CornerRadius, ThemeSettings};

/// 8-bit RGBA. Every token this crate resolves is opaque (`a: 255`): a
/// translucent color changes with whatever is drawn under it, so each
/// ground gets its own pre-blended set instead (see [`GroundTokens`]). The
/// alpha channel only exists because Slint's `Color` has one.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rgba {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

impl Rgba {
    pub const fn opaque(rgb: RgbColor) -> Self {
        Self {
            r: rgb.r,
            g: rgb.g,
            b: rgb.b,
            a: 255,
        }
    }
}

/// Pre-composites `fg` over `bg` at `alpha`, returning an opaque result --
/// ported from `Theme.qml`'s `opaqueBlend()`.
fn opaque_blend(fg: RgbColor, bg: RgbColor, alpha: f32) -> RgbColor {
    let mix = |f: u8, b: u8| -> u8 { (f as f32 * alpha + b as f32 * (1.0 - alpha)).round() as u8 };
    RgbColor::new(mix(fg.r, bg.r), mix(fg.g, bg.g), mix(fg.b, bg.b))
}

/// `fg` blended over `ground`, starting at `alpha` and raised until it
/// reaches `min_ratio` against every one of `backings` (or is `fg` itself).
/// So a quiet text color stays as quiet as the palette allows, but never
/// below the floor on any of the colors it is drawn over.
fn blend_with_contrast(
    fg: RgbColor,
    ground: RgbColor,
    backings: &[RgbColor],
    alpha: f32,
    min_ratio: f32,
) -> RgbColor {
    let mut a = alpha;
    loop {
        let c = opaque_blend(fg, ground, a);
        if a >= 1.0
            || backings
                .iter()
                .all(|&bg| contrast_ratio(c, bg) >= min_ratio)
        {
            return c;
        }
        a = (a + 0.02).min(1.0);
    }
}

/// Contrast floors for the quiet text colors: WCAG AA for body text, and
/// the 3:1 that AA asks of disabled/incidental UI.
pub const TEXT_SECONDARY_MIN_CONTRAST: f32 = 4.5;
pub const TEXT_DISABLED_MIN_CONTRAST: f32 = 3.0;

/// Mirrors `ui/tokens.slint`'s `Tokens` global 1:1.
#[derive(Debug, Clone, Copy)]
pub struct ColorTokens {
    pub background: Rgba,
    pub surface: Rgba,
    pub surface_raised: Rgba,
    pub accent: Rgba,
    /// Text drawn on a solid `accent` / `destructive` fill.
    pub text_on_accent: Rgba,
    pub text_on_destructive: Rgba,
    pub text_primary: Rgba,
    pub destructive: Rgba,
    /// A solid `accent` fill under the pointer / pressed.
    pub accent_hover: Rgba,
    pub accent_pressed: Rgba,
    pub destructive_hover: Rgba,
    pub destructive_pressed: Rgba,
    /// Positive state (a connected radio, a "done" badge).
    pub success: Rgba,
    /// What to draw on `background` (the content area).
    pub on_background: GroundTokens,
    /// What to draw on `surface` (the chrome).
    pub on_surface: GroundTokens,
    /// What to draw on `surface_raised`.
    pub on_raised: GroundTokens,
}

/// The colors that are drawn on top of one solid ground, each already
/// blended against that ground. A view picks the set for the ground it
/// sits on instead of tinting a color at the point of use.
#[derive(Debug, Clone, Copy)]
pub struct GroundTokens {
    pub border: Rgba,
    pub divider: Rgba,
    pub hover: Rgba,
    pub pressed: Rgba,
    /// A selected row/tile.
    pub selected: Rgba,
    pub text_secondary: Rgba,
    pub text_disabled: Rgba,
    /// A light wash of the accent (a selected day, a text selection).
    pub accent_soft: Rgba,
    /// A heavier wash of the accent (a marker, a highlighted range).
    pub accent_strong: Rgba,
    /// A border under the pointer (stronger than `border`).
    pub border_hover: Rgba,
    /// Washes of the destructive / success colors (an error banner, a badge).
    pub destructive_soft: Rgba,
    pub destructive_border: Rgba,
    pub success_soft: Rgba,
    pub success_border: Rgba,
}

impl ColorTokens {
    /// Every color under the name of its `Tokens` property in
    /// `ui/tokens.slint` (`text-secondary`, `hover-on-surface`, ...).
    pub fn slint_properties(&self) -> Vec<(String, Rgba)> {
        let mut out: Vec<(String, Rgba)> = vec![
            ("background".into(), self.background),
            ("surface".into(), self.surface),
            ("surface-raised".into(), self.surface_raised),
            ("accent".into(), self.accent),
            ("text-on-accent".into(), self.text_on_accent),
            ("text-on-destructive".into(), self.text_on_destructive),
            ("text-primary".into(), self.text_primary),
            ("destructive".into(), self.destructive),
            ("accent-hover".into(), self.accent_hover),
            ("accent-pressed".into(), self.accent_pressed),
            ("destructive-hover".into(), self.destructive_hover),
            ("destructive-pressed".into(), self.destructive_pressed),
            ("success".into(), self.success),
        ];
        for (suffix, g) in [
            ("", &self.on_background),
            ("-on-surface", &self.on_surface),
            ("-on-raised", &self.on_raised),
        ] {
            for (name, color) in [
                ("border", g.border),
                ("border-hover", g.border_hover),
                ("divider", g.divider),
                ("hover", g.hover),
                ("pressed", g.pressed),
                ("selected", g.selected),
                ("text-secondary", g.text_secondary),
                ("text-disabled", g.text_disabled),
                ("accent-soft", g.accent_soft),
                ("accent-strong", g.accent_strong),
                ("destructive-soft", g.destructive_soft),
                ("destructive-border", g.destructive_border),
                ("success-soft", g.success_soft),
                ("success-border", g.success_border),
            ] {
                out.push((format!("{name}{suffix}"), color));
            }
        }
        out
    }
}

/// A fixed semantic constant (`Theme.qml`'s `negativeTextColor`)
/// -- not persisted/customizable, matches upstream: it's a hardcoded
/// constant there too, independent of the active scheme/accent.
const DESTRUCTIVE: RgbColor = RgbColor::new(0xda, 0x44, 0x53);
/// Likewise fixed: the "positive" green (`#10b981`, emerald-500).
const SUCCESS: RgbColor = RgbColor::new(0x10, 0xb9, 0x81);

const WHITE: RgbColor = RgbColor::new(0xff, 0xff, 0xff);
const BLACK: RgbColor = RgbColor::new(0x00, 0x00, 0x00);

fn ground_tokens(ground: RgbColor, text: RgbColor, accent: RgbColor) -> GroundTokens {
    let o = Rgba::opaque;
    // Quiet text is drawn over the ground and over what it turns into under
    // the pointer / when selected.
    let hover = opaque_blend(accent, ground, 0.15);
    let selected = opaque_blend(accent, ground, 0.25);
    let backings = [ground, hover, selected];
    GroundTokens {
        border: o(opaque_blend(text, ground, 0.4)),
        divider: o(opaque_blend(text, ground, 0.5)),
        hover: o(hover),
        pressed: o(opaque_blend(accent, ground, 0.5)),
        selected: o(selected),
        text_secondary: o(blend_with_contrast(
            text,
            ground,
            &backings,
            0.65,
            TEXT_SECONDARY_MIN_CONTRAST,
        )),
        text_disabled: o(blend_with_contrast(
            text,
            ground,
            &backings,
            0.45,
            TEXT_DISABLED_MIN_CONTRAST,
        )),
        accent_soft: o(opaque_blend(accent, ground, 0.35)),
        accent_strong: o(opaque_blend(accent, ground, 0.6)),
        border_hover: o(opaque_blend(text, ground, 0.6)),
        destructive_soft: o(opaque_blend(DESTRUCTIVE, ground, 0.2)),
        destructive_border: o(opaque_blend(DESTRUCTIVE, ground, 0.5)),
        success_soft: o(opaque_blend(SUCCESS, ground, 0.2)),
        success_border: o(opaque_blend(SUCCESS, ground, 0.5)),
    }
}

/// Derives every `ColorTokens` field from one composed palette:
/// - `background` = the view/content color set's background (`base`).
/// - `surface`/`surface-raised` = the header/chrome color set's background
///   (`button`) / the `light` role (a bevel-highlight shade).
/// - Everything drawn over a ground is blended against that ground, once
///   per ground (`on_background`, `on_surface`, `on_raised`), all opaque.
fn resolve_colors(preset: palette::PalettePreset, accent: RgbColor) -> ColorTokens {
    let composed = palette::compose_palette(preset, accent);
    ColorTokens {
        background: Rgba::opaque(composed.base),
        surface: Rgba::opaque(composed.button),
        surface_raised: Rgba::opaque(composed.light),
        accent: Rgba::opaque(composed.highlight),
        text_on_accent: Rgba::opaque(composed.highlighted_text),
        text_on_destructive: Rgba::opaque(palette::contrasting_text_color(DESTRUCTIVE)),
        text_primary: Rgba::opaque(composed.text),
        destructive: Rgba::opaque(DESTRUCTIVE),
        accent_hover: Rgba::opaque(opaque_blend(WHITE, composed.highlight, 0.12)),
        accent_pressed: Rgba::opaque(opaque_blend(BLACK, composed.highlight, 0.2)),
        destructive_hover: Rgba::opaque(opaque_blend(WHITE, DESTRUCTIVE, 0.12)),
        destructive_pressed: Rgba::opaque(opaque_blend(BLACK, DESTRUCTIVE, 0.2)),
        success: Rgba::opaque(SUCCESS),
        on_background: ground_tokens(composed.base, composed.text, composed.highlight),
        on_surface: ground_tokens(composed.button, composed.text, composed.highlight),
        on_raised: ground_tokens(composed.light, composed.text, composed.highlight),
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

fn corner_radius_px(preset: CornerRadius) -> f32 {
    match preset {
        CornerRadius::Circle => 9999.0,
        CornerRadius::Large => 14.0,
        CornerRadius::Medium => 8.0,
        CornerRadius::Small => 4.0,
        CornerRadius::Disabled => 0.0,
    }
}

fn border_width_px(preset: BorderWidth) -> f32 {
    match preset {
        BorderWidth::Disabled => 0.0,
        BorderWidth::Thin => 0.5,
        BorderWidth::Default => 1.0,
        BorderWidth::Thick => 2.0,
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

fn animation_speed_multiplier(preset: AnimationSpeed) -> f32 {
    match preset {
        AnimationSpeed::Slow => 1.75,
        AnimationSpeed::Fast => 0.5,
        AnimationSpeed::Normal => 1.2,
    }
}

fn scaled_duration(base_ms: f32, multiplier: f32, enabled: bool) -> i32 {
    if enabled {
        (base_ms * multiplier).round() as i32
    } else {
        0
    }
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

/// Resolves `settings` into concrete token values. Pure arithmetic --
/// cheap enough to call again on every settings change rather than patching
/// individual fields.
pub fn resolve(settings: &ThemeSettings) -> ResolvedTheme {
    let accent = settings
        .accent
        .unwrap_or_else(|| palette::default_accent_for(&settings.variant));
    let preset = palette::preset_by_id(&settings.variant);

    let multiplier = animation_speed_multiplier(settings.animation_speed);
    let duration = |base_ms: f32| scaled_duration(base_ms, multiplier, settings.animations_enabled);

    ResolvedTheme {
        colors: resolve_colors(preset, accent),
        shape: ShapeTokens {
            corner_radius_px: corner_radius_px(settings.corner_radius),
            border_width_px: border_width_px(settings.border_width),
        },
        spacing: SpacingTokens {
            small_px: BASE_SPACING_SMALL_PX * settings.ui_scale,
            medium_px: BASE_SPACING_MEDIUM_PX * settings.ui_scale,
            large_px: BASE_SPACING_LARGE_PX * settings.ui_scale,
        },
        animation: AnimationTokens {
            enabled: settings.animations_enabled,
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
    fn corner_radius_presets() {
        assert_eq!(corner_radius_px(CornerRadius::Circle), 9999.0);
        assert_eq!(corner_radius_px(CornerRadius::Large), 14.0);
        assert_eq!(corner_radius_px(CornerRadius::Medium), 8.0);
        assert_eq!(corner_radius_px(CornerRadius::Small), 4.0);
        assert_eq!(corner_radius_px(CornerRadius::Disabled), 0.0);
    }

    #[test]
    fn border_width_presets() {
        assert_eq!(border_width_px(BorderWidth::Disabled), 0.0);
        assert_eq!(border_width_px(BorderWidth::Thin), 0.5);
        assert_eq!(border_width_px(BorderWidth::Default), 1.0);
        assert_eq!(border_width_px(BorderWidth::Thick), 2.0);
    }

    #[test]
    fn animations_disabled_zeroes_every_duration() {
        assert_eq!(scaled_duration(50.0, 1.75, false), 0);
        assert_eq!(scaled_duration(500.0, 0.5, false), 0);
    }

    #[test]
    fn animation_speed_scales_base_durations() {
        assert_eq!(
            scaled_duration(50.0, animation_speed_multiplier(AnimationSpeed::Slow), true),
            88
        );
        assert_eq!(
            scaled_duration(
                500.0,
                animation_speed_multiplier(AnimationSpeed::Fast),
                true
            ),
            250
        );
        assert_eq!(
            scaled_duration(
                300.0,
                animation_speed_multiplier(AnimationSpeed::Normal),
                true
            ),
            360
        );
    }

    #[test]
    fn opaque_blend_matches_the_qml_formula() {
        let white = RgbColor::new(255, 255, 255);
        let black = RgbColor::new(0, 0, 0);
        assert_eq!(
            opaque_blend(white, black, 0.5),
            RgbColor::new(128, 128, 128)
        );
    }

    #[test]
    fn ui_scale_scales_spacing_only() {
        let theme = resolve(&ThemeSettings {
            ui_scale: 2.0,
            ..ThemeSettings::default()
        });
        assert_eq!(theme.spacing.small_px, 8.0);
        assert_eq!(theme.spacing.medium_px, 16.0);
        assert_eq!(theme.spacing.large_px, 32.0);
        assert_eq!(
            theme.shape.corner_radius_px, 4.0,
            "shape is unaffected by ui_scale"
        );
    }

    #[test]
    fn default_settings_use_the_dark_variant_with_its_own_accent() {
        let theme = resolve(&ThemeSettings::default());
        let accent = palette::DEFAULT_ACCENT;
        assert_eq!(theme.colors.accent, Rgba::opaque(accent));
        let dark = palette::DARK_PRESET;
        assert_eq!(theme.colors.background, Rgba::opaque(dark.base));
    }

    #[test]
    fn explicit_accent_and_variant_override_the_defaults() {
        let accent = RgbColor::new(0x11, 0x22, 0x33);
        let theme = resolve(&ThemeSettings {
            variant: "catppuccin-mocha".to_string(),
            accent: Some(accent),
            ..ThemeSettings::default()
        });
        assert_eq!(theme.colors.accent, Rgba::opaque(accent));
        let mocha = palette::preset_by_id("catppuccin-mocha");
        assert_eq!(theme.colors.background, Rgba::opaque(mocha.base));
    }

    #[test]
    fn variant_accent_is_used_when_none_is_given() {
        let theme = resolve(&ThemeSettings {
            variant: "catppuccin-mocha".to_string(),
            ..ThemeSettings::default()
        });
        assert_eq!(
            theme.colors.accent,
            Rgba::opaque(palette::default_accent_for("catppuccin-mocha"))
        );
    }

    #[test]
    fn every_token_is_opaque() {
        for scheme in palette::presets::SCHEMES {
            for v in scheme.variants {
                let c = resolve(&ThemeSettings {
                    variant: v.id.to_string(),
                    ..ThemeSettings::default()
                })
                .colors;
                for g in [c.on_background, c.on_surface, c.on_raised] {
                    for t in [
                        g.border,
                        g.divider,
                        g.hover,
                        g.pressed,
                        g.selected,
                        g.text_secondary,
                        g.text_disabled,
                        g.accent_soft,
                        g.accent_strong,
                        g.border_hover,
                        g.destructive_soft,
                        g.destructive_border,
                        g.success_soft,
                        g.success_border,
                    ] {
                        assert_eq!(t.a, 255, "{}", v.id);
                    }
                }
            }
        }
    }

    #[test]
    fn quiet_text_stays_readable_on_every_ground_of_every_variant() {
        let rgb = |t: Rgba| RgbColor::new(t.r, t.g, t.b);
        for scheme in palette::presets::SCHEMES {
            for v in scheme.variants {
                let c = resolve(&ThemeSettings {
                    variant: v.id.to_string(),
                    ..ThemeSettings::default()
                })
                .colors;
                for (name, ground, g) in [
                    ("background", c.background, c.on_background),
                    ("surface", c.surface, c.on_surface),
                    ("raised", c.surface_raised, c.on_raised),
                ] {
                    // On the ground itself the floors are absolute; under the
                    // pointer or when selected they are as high as the body
                    // text itself reaches there (the accent wash can leave
                    // even that short of them).
                    for (over, backing, strict) in [
                        ("", rgb(ground), true),
                        (" hovered", rgb(g.hover), false),
                        (" selected", rgb(g.selected), false),
                    ] {
                        let cap = contrast_ratio(rgb(c.text_primary), backing);
                        let floor = |min: f32| if strict { min } else { min.min(cap) - 0.05 };
                        let s = contrast_ratio(rgb(g.text_secondary), backing);
                        let d = contrast_ratio(rgb(g.text_disabled), backing);
                        assert!(
                            s >= floor(TEXT_SECONDARY_MIN_CONTRAST),
                            "{} secondary on{over} {name}: {s}",
                            v.id
                        );
                        assert!(
                            d >= floor(TEXT_DISABLED_MIN_CONTRAST),
                            "{} disabled on{over} {name}: {d}",
                            v.id
                        );
                    }
                }
            }
        }
    }

    /// `ui/tokens.slint`'s literal defaults are the default theme resolved;
    /// this fails (and prints the lines to paste) when they drift apart.
    #[test]
    fn tokens_slint_defaults_match_the_resolved_default_theme() {
        let slint = include_str!("../../origami/ui/tokens.slint");
        let declared = |name: &str| -> Option<String> {
            let prefix = format!("in-out property <color> {name}: ");
            slint.lines().find_map(|l| {
                l.trim()
                    .strip_prefix(&prefix)
                    .map(|v| v.trim_end_matches(';').to_string())
            })
        };
        let mut wrong = Vec::new();
        for (name, c) in resolve(&ThemeSettings::default()).colors.slint_properties() {
            let want = format!("#{:02x}{:02x}{:02x}", c.r, c.g, c.b);
            if declared(&name).as_deref() != Some(want.as_str()) {
                wrong.push(format!("    in-out property <color> {name}: {want};"));
            }
        }
        assert!(
            wrong.is_empty(),
            "tokens.slint is out of date:\n{}",
            wrong.join("\n")
        );
    }

    /// Same check as `tokens_slint_defaults_match_the_resolved_default_theme`,
    /// for `origami-mobile`'s `ThemeColors` global -- its roles are a named
    /// subset of `ColorTokens`/`GroundTokens` (see
    /// `origami_mobile::push_mobile_color_tokens!`'s field list, which this
    /// mirrors), not `slint_properties()`'s full desktop vocabulary.
    #[test]
    fn mobile_theme_colors_defaults_match_the_resolved_default_theme() {
        let slint = include_str!("../../origami-mobile/ui/tokens.slint");
        let declared = |name: &str| -> Option<String> {
            let prefix = format!("in-out property <color> {name}: ");
            slint.lines().find_map(|l| {
                l.trim()
                    .strip_prefix(&prefix)
                    .map(|v| v.trim_end_matches(';').to_string())
            })
        };
        let c = resolve(&ThemeSettings::default()).colors;
        let mapping: [(&str, Rgba); 8] = [
            ("danger", c.destructive),
            ("success", c.success),
            ("separator", c.on_background.divider),
            ("muted", c.on_background.text_secondary),
            ("page-background", c.background),
            ("surface", c.surface),
            ("surface-elevated", c.surface_raised),
            ("card-border", c.on_raised.border),
        ];
        let mut wrong = Vec::new();
        for (name, color) in mapping {
            let want = format!("#{:02x}{:02x}{:02x}", color.r, color.g, color.b);
            if declared(name).as_deref() != Some(want.as_str()) {
                wrong.push(format!("    in-out property <color> {name}: {want};"));
            }
        }
        assert!(
            wrong.is_empty(),
            "origami-mobile's ui/tokens.slint ThemeColors is out of date:\n{}",
            wrong.join("\n")
        );
    }
}
