//! What an app chooses about its theme. Plain data, no persistence: an app
//! that wants to remember the user's choices stores them however it likes
//! and builds a `ThemeSettings` from them at startup.

use crate::palette::{PalettePreset, RgbColor};

/// Corner rounding of controls. `Circle` is fully round (pill shapes).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum CornerRadius {
    Disabled,
    #[default]
    Small,
    Medium,
    Large,
    Circle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BorderWidth {
    Disabled,
    Thin,
    #[default]
    Default,
    Thick,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AnimationSpeed {
    Slow,
    #[default]
    Normal,
    Fast,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ThemeSettings {
    /// A palette variant id from [`crate::palette::presets::SCHEMES`], e.g.
    /// `"dark"`, `"light"`, `"catppuccin-mocha"`. An unknown id falls back
    /// to the light preset -- unless `preset_override` is set, in which
    /// case this is only used to pick the default accent for `accent:
    /// None` and is otherwise ignored.
    pub variant: String,
    /// The accent color. `None` uses the variant's own signature accent.
    pub accent: Option<RgbColor>,
    /// A full base palette to use instead of looking `variant` up in the
    /// named preset registry -- e.g. one read from the OS (see
    /// `crate::os`, behind the `os` feature). `None` keeps the ordinary
    /// `variant`-id lookup.
    pub preset_override: Option<PalettePreset>,
    pub corner_radius: CornerRadius,
    pub border_width: BorderWidth,
    pub animation_speed: AnimationSpeed,
    /// When false every animation duration resolves to zero.
    pub animations_enabled: bool,
    /// Multiplies the spacing tokens only (not shapes or fonts).
    pub ui_scale: f32,
}

impl Default for ThemeSettings {
    fn default() -> Self {
        Self {
            variant: "dark".to_string(),
            accent: None,
            preset_override: None,
            corner_radius: CornerRadius::default(),
            border_width: BorderWidth::default(),
            animation_speed: AnimationSpeed::default(),
            animations_enabled: true,
            ui_scale: 1.0,
        }
    }
}
