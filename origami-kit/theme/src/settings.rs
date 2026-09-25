//! What an app chooses about its theme. Plain data, no persistence: an app
//! that wants to remember the user's choices stores them however it likes
//! and builds a `ThemeSettings` from them at startup.

use crate::palette::RgbColor;

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
    /// to the light preset.
    pub variant: String,
    /// The accent color. `None` uses the variant's own signature accent.
    pub accent: Option<RgbColor>,
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
            corner_radius: CornerRadius::default(),
            border_width: BorderWidth::default(),
            animation_speed: AnimationSpeed::default(),
            animations_enabled: true,
            ui_scale: 1.0,
        }
    }
}
