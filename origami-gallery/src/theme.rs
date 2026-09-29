// Glue between `origami-theme`'s resolved tokens and the shared `Tokens`
// global (`@origami/tokens.slint`) -- ~40 lines of pure Rust-to-Slint
// property pushing, duplicated per app rather than shared since there is
// no other logic worth factoring into a crate over.

use origami_theme::{ResolvedTheme, Rgba, ThemeSettings};
use slint::{Color, ComponentHandle};

use crate::{AppWindow, Tokens};

fn color(rgba: Rgba) -> Color {
    Color::from_argb_u8(rgba.a, rgba.r, rgba.g, rgba.b)
}

fn apply(app: &AppWindow, theme: &ResolvedTheme) {
    let tokens = app.global::<Tokens>();

    origami::push_color_tokens!(&tokens, theme.colors, color);

    tokens.set_corner_radius(theme.shape.corner_radius_px);
    tokens.set_border_width(theme.shape.border_width_px);

    tokens.set_spacing_small(theme.spacing.small_px);
    tokens.set_spacing_medium(theme.spacing.medium_px);
    tokens.set_spacing_large(theme.spacing.large_px);

    tokens.set_anim_very_short(theme.animation.very_short_ms);
    tokens.set_anim_short(theme.animation.short_ms);
    tokens.set_anim_long(theme.animation.long_ms);
    tokens.set_anim_very_long(theme.animation.very_long_ms);
}

/// The gallery has no settings of its own: it shows the default theme.
pub fn apply_default(app: &AppWindow) {
    apply(app, &origami_theme::resolve(&ThemeSettings::default()));
}
