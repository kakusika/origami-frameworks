//! Ayame's persisted settings, shared between `ayame-settings` (the editor
//! GUI) and `crates/qml6` (the "Ayame" QQC2 style itself, which reads this
//! at startup and on every change instead of depending on a host app to
//! supply values). Written to `~/.config/ayamerc` -- an extension-less
//! rc-file name, consistent with `docs/roadmap.tm`'s note, directly under
//! the XDG config dir (not nested in an `ayame/` subdirectory).
//!
//! `exceptions` is aimed at the not-yet-implemented `kdecoration6` KDE
//! plugin (still an empty stub dir, not in the workspace) -- kept around
//! since its shape doesn't depend on that plugin existing yet. `general`/
//! `decoration` (window-border/shadow/titlebar knobs owned by the
//! not-yet-implemented `kstyle6`/`kdecoration6` plugins) were removed
//! entirely rather than kept as unused struct fields with no UI behind
//! them; revive them once those plugins exist to actually consume them.
//! `style` is aimed at `crates/qml6`, the actually-working runtime today.

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExceptionRule {
    pub property_type: String,
    pub property_match: String,
    pub hide_titlebar: bool,
    pub border_size: String,
}

/// The settings `crates/qml6`'s QML-exposed objects (`ThemeSettings`,
/// `FontSettings`, `CornerRadiusSettings`, `BorderWidthSettings`,
/// `AnimationSettings`, `UiScaleSettings`, `StyleInfo`) load at startup and
/// persist on every setter call. Option strings match the fixed presets
/// `crates/qml6/qml/theme/Units.qml` maps them through (`_cornerRadiusPresets`,
/// `_borderWidthPresets`, `_animationSpeedPresets`) -- not free-form.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StyleSettings {
    /// "system", or a flat scheme/variant id from `ayame_colors::presets`
    /// (e.g. "dark", "catppuccin-mocha").
    pub theme_mode: String,
    /// "#RRGGBB".
    pub accent_color: String,
    /// Empty string means "use the system default family".
    pub font_family: String,
    /// 0.0 means "use the system default point size".
    pub font_point_size: f64,
    /// One of "disabled" | "small" | "medium" | "large" | "circle".
    pub corner_radius: String,
    /// One of "thin" | "default" | "thick".
    pub border_width: String,
    /// One of "slow" | "normal" | "fast".
    pub animation_speed: String,
    pub animations_enabled: bool,
    pub ui_scale: f64,
    /// The last Qt application style the user picked (`StyleInfo::save_style`).
    pub saved_style: String,
}

impl Default for StyleSettings {
    fn default() -> Self {
        Self {
            theme_mode: "system".to_string(),
            // Mirrors ayame_colors::DEFAULT_ACCENT -- not imported directly
            // so this crate stays free of the cxx-qt-lib/Qt build
            // dependency that crate carries, since ayame-config is also
            // meant to be usable from the (currently plain-C++,
            // non-cxx-qt) future kstyle6/kdecoration6 plugins.
            accent_color: "#3daee9".to_string(),
            font_family: String::new(),
            font_point_size: 0.0,
            corner_radius: "medium".to_string(),
            border_width: "default".to_string(),
            animation_speed: "normal".to_string(),
            animations_enabled: true,
            ui_scale: 1.0,
            saved_style: String::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct Settings {
    pub exceptions: Vec<ExceptionRule>,
    pub style: StyleSettings,
}

impl Settings {
    /// `~/.config/ayamerc` directly -- not `~/.config/ayame/ayamerc`. Uses
    /// `BaseDirs` (the bare XDG config dir) rather than `ProjectDirs`
    /// (which would nest it under an app-specific subdirectory) for
    /// exactly that reason.
    pub fn config_path() -> Option<PathBuf> {
        directories::BaseDirs::new().map(|dirs| dirs.config_dir().join("ayamerc"))
    }

    pub fn load() -> Self {
        if let Some(path) = Self::config_path() {
            if path.exists() {
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(settings) = toml::from_str(&content) {
                        return settings;
                    }
                }
            }
        }
        Self::default()
    }

    pub fn save(&self) -> anyhow::Result<()> {
        if let Some(path) = Self::config_path() {
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            let content = toml::to_string_pretty(self)?;
            fs::write(path, content)?;
        }
        Ok(())
    }
}
