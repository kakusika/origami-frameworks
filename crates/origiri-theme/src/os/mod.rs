//! Reads the OS's own light/dark preference and accent color, so an app
//! can offer a "follow the system" theme choice alongside its own named
//! presets.
//!
//! [`detect`] is a one-shot snapshot taken when called (app startup, or
//! whenever the user picks "System" in a theme picker) -- it does not
//! watch for OS-side changes while the app keeps running. That's a
//! deliberate, separate follow-up: a `watch`/`subscribe` entry point can
//! sit alongside `detect` later without reshaping this API.

#[cfg_attr(target_os = "windows", path = "accent/windows.rs")]
#[cfg_attr(target_os = "macos", path = "accent/macos.rs")]
#[cfg_attr(target_os = "linux", path = "accent/linux.rs")]
#[cfg_attr(
    not(any(target_os = "windows", target_os = "macos", target_os = "linux")),
    path = "accent/none.rs"
)]
mod accent;

#[cfg_attr(target_os = "linux", path = "full_palette/linux.rs")]
#[cfg_attr(not(target_os = "linux"), path = "full_palette/none.rs")]
mod full_palette;

use crate::palette::{PalettePreset, RgbColor};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ColorScheme {
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OsTheme {
    pub color_scheme: ColorScheme,
    /// `None` when the OS has no single accent color set (e.g. macOS's
    /// "Multicolor" option, or a Linux desktop that doesn't implement the
    /// `org.freedesktop.appearance` portal setting).
    pub accent: Option<RgbColor>,
    /// A full base palette (window/base/button/tooltip colors, not just
    /// the accent), when the desktop exposes one -- today, only Linux
    /// via `~/.config/kdeglobals`. `None` everywhere else, and on Linux
    /// when that file is missing or doesn't parse.
    pub full_palette: Option<PalettePreset>,
}

/// Snapshots the OS's current light/dark preference, accent color, and
/// (where available) full base palette. Never fails -- an OS/desktop that
/// doesn't expose one of these just yields `ColorScheme::Light` (matching
/// [`dark_light`]'s own documented fallback for `Mode::Unspecified`)
/// and/or `None`.
pub fn detect() -> OsTheme {
    let color_scheme = match dark_light::detect() {
        Ok(dark_light::Mode::Dark) => ColorScheme::Dark,
        Ok(dark_light::Mode::Light) | Ok(dark_light::Mode::Unspecified) | Err(_) => {
            ColorScheme::Light
        }
    };
    OsTheme {
        color_scheme,
        accent: accent::detect(),
        full_palette: full_palette::detect(),
    }
}
