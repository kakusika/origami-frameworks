//! Slint-side widgets and build-time wiring (`ui/*.slint`, `build.rs`'s
//! `UI_DIR`). The pane tree/layout/drag-drop logic lives in `origiri-panes`
//! (toolkit-independent, no Slint dependency) -- a consuming app depends on
//! both crates directly and assembles them itself; this crate only
//! supplies the Slint widgets (`PaneHost`, `PaneManager`, ...), which take
//! plain Slint structs and have no Rust-level dependency on
//! `origiri-panes`.

/// Pushes every color of an `origiri_theme::ColorTokens` onto an app's
/// generated `Tokens` global. The global's setters are generated per app
/// (`slint::include_modules!`), so this expands at the call site:
///
/// ```ignore
/// origiri_slint::push_color_tokens!(app.global::<Tokens>(), theme.colors, color);
/// ```
///
/// where `color` turns an `origiri_theme::Rgba` into a `slint::Color`. Keep
/// the list in step with `ui/tokens.slint`.
#[macro_export]
macro_rules! push_color_tokens {
    ($tokens:expr, $colors:expr, $color:expr) => {{
        let tokens = $tokens;
        let c = &$colors;
        tokens.set_background($color(c.background));
        tokens.set_surface($color(c.surface));
        tokens.set_surface_raised($color(c.surface_raised));
        tokens.set_accent($color(c.accent));
        tokens.set_text_on_accent($color(c.text_on_accent));
        tokens.set_text_on_destructive($color(c.text_on_destructive));
        tokens.set_text_primary($color(c.text_primary));
        tokens.set_destructive($color(c.destructive));
        tokens.set_accent_hover($color(c.accent_hover));
        tokens.set_accent_pressed($color(c.accent_pressed));
        tokens.set_destructive_hover($color(c.destructive_hover));
        tokens.set_destructive_pressed($color(c.destructive_pressed));
        tokens.set_success($color(c.success));

        tokens.set_border($color(c.on_background.border));
        tokens.set_divider($color(c.on_background.divider));
        tokens.set_hover($color(c.on_background.hover));
        tokens.set_pressed($color(c.on_background.pressed));
        tokens.set_selected($color(c.on_background.selected));
        tokens.set_text_secondary($color(c.on_background.text_secondary));
        tokens.set_text_disabled($color(c.on_background.text_disabled));
        tokens.set_accent_soft($color(c.on_background.accent_soft));
        tokens.set_accent_strong($color(c.on_background.accent_strong));
        tokens.set_border_hover($color(c.on_background.border_hover));
        tokens.set_destructive_soft($color(c.on_background.destructive_soft));
        tokens.set_destructive_border($color(c.on_background.destructive_border));
        tokens.set_success_soft($color(c.on_background.success_soft));
        tokens.set_success_border($color(c.on_background.success_border));

        tokens.set_border_on_surface($color(c.on_surface.border));
        tokens.set_divider_on_surface($color(c.on_surface.divider));
        tokens.set_hover_on_surface($color(c.on_surface.hover));
        tokens.set_pressed_on_surface($color(c.on_surface.pressed));
        tokens.set_selected_on_surface($color(c.on_surface.selected));
        tokens.set_text_secondary_on_surface($color(c.on_surface.text_secondary));
        tokens.set_text_disabled_on_surface($color(c.on_surface.text_disabled));
        tokens.set_accent_soft_on_surface($color(c.on_surface.accent_soft));
        tokens.set_accent_strong_on_surface($color(c.on_surface.accent_strong));
        tokens.set_border_hover_on_surface($color(c.on_surface.border_hover));
        tokens.set_destructive_soft_on_surface($color(c.on_surface.destructive_soft));
        tokens.set_destructive_border_on_surface($color(c.on_surface.destructive_border));
        tokens.set_success_soft_on_surface($color(c.on_surface.success_soft));
        tokens.set_success_border_on_surface($color(c.on_surface.success_border));

        tokens.set_border_on_raised($color(c.on_raised.border));
        tokens.set_divider_on_raised($color(c.on_raised.divider));
        tokens.set_hover_on_raised($color(c.on_raised.hover));
        tokens.set_pressed_on_raised($color(c.on_raised.pressed));
        tokens.set_selected_on_raised($color(c.on_raised.selected));
        tokens.set_text_secondary_on_raised($color(c.on_raised.text_secondary));
        tokens.set_text_disabled_on_raised($color(c.on_raised.text_disabled));
        tokens.set_accent_soft_on_raised($color(c.on_raised.accent_soft));
        tokens.set_accent_strong_on_raised($color(c.on_raised.accent_strong));
        tokens.set_border_hover_on_raised($color(c.on_raised.border_hover));
        tokens.set_destructive_soft_on_raised($color(c.on_raised.destructive_soft));
        tokens.set_destructive_border_on_raised($color(c.on_raised.destructive_border));
        tokens.set_success_soft_on_raised($color(c.on_raised.success_soft));
        tokens.set_success_border_on_raised($color(c.on_raised.success_border));
    }};
}
