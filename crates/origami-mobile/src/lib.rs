//! Generic, app-agnostic mobile Slint widgets (`ui/tokens.slint`,
//! `ui/icons.slint`, `ui/components.slint`), kept independent of any one
//! consuming app's own domain-specific components. Mirrors `origami`'s
//! `links` + `cargo:UI_DIR=...` build-script convention and `ui/` file
//! split.

/// Pushes every color of an `origami_theme::ColorTokens` onto an app's
/// generated `ThemeColors` global and flips `Theme.use-custom` to `true`
/// in the same call -- unlike `origami::push_color_tokens!`, which only
/// pushes fields (desktop's `Tokens` global has no system/custom switch
/// to flip), this one also owns the switch so a caller can't push colors
/// and forget to flip it, leaving the UI silently still on OS colors.
/// `warning` has no `origami-theme` equivalent (its own `destructive`/
/// `success` are fixed constants too) and is deliberately left out --
/// `Colors.warning` always reads from `SystemColors`, never themed.
///
/// Expands at the call site:
///
/// ```ignore
/// origami_mobile::push_mobile_color_tokens!(
///     app.global::<ThemeColors>(), app.global::<Theme>(), theme.colors, color
/// );
/// ```
///
/// where `color` turns an `origami_theme::Rgba` into a `slint::Color`.
/// Keep the field list in step with `ui/tokens.slint`'s `ThemeColors`.
#[macro_export]
macro_rules! push_mobile_color_tokens {
    ($theme_colors:expr, $theme_flag:expr, $colors:expr, $color:expr) => {{
        let tokens = $theme_colors;
        let c = &$colors;
        tokens.set_danger($color(c.destructive));
        tokens.set_success($color(c.success));
        tokens.set_separator($color(c.on_background.divider));
        tokens.set_muted($color(c.on_background.text_secondary));
        tokens.set_page_background($color(c.background));
        tokens.set_surface($color(c.surface));
        tokens.set_surface_elevated($color(c.surface_raised));
        tokens.set_card_border($color(c.on_raised.border));
        $theme_flag.set_use_custom(true);
    }};
}
