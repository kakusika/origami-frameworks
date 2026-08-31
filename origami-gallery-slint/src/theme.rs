// Glue between `ayame-slint`'s resolved settings and the shared `Tokens`
// global -- identical shape to `cettila-slint`'s own `src/theme.rs`,
// duplicated here rather than shared since it's ~40 lines of pure
// Rust-to-Slint property pushing with no other logic worth factoring
// into a crate over.

use ayame_slint::{ResolvedTheme, Rgba};
use slint::{Color, ComponentHandle};

use crate::{AppWindow, Tokens};

fn color(rgba: Rgba) -> Color {
    Color::from_argb_u8(rgba.a, rgba.r, rgba.g, rgba.b)
}

fn apply(app: &AppWindow, theme: &ResolvedTheme) {
    let tokens = app.global::<Tokens>();

    tokens.set_background(color(theme.colors.background));
    tokens.set_surface(color(theme.colors.surface));
    tokens.set_surface_raised(color(theme.colors.surface_raised));
    tokens.set_border(color(theme.colors.border));
    tokens.set_divider(color(theme.colors.divider));
    tokens.set_hover(color(theme.colors.hover));
    tokens.set_pressed(color(theme.colors.pressed));
    tokens.set_accent(color(theme.colors.accent));
    tokens.set_text_primary(color(theme.colors.text_primary));
    tokens.set_text_secondary(color(theme.colors.text_secondary));
    tokens.set_text_disabled(color(theme.colors.text_disabled));
    tokens.set_destructive(color(theme.colors.destructive));
    tokens.set_selected_surface(color(theme.colors.selected_surface));

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

pub fn load_and_apply(app: &AppWindow) {
    let theme = ayame_slint::resolve();
    apply(app, &theme);
}
