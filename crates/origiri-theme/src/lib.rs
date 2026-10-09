//! Origiri's theme: named color palettes, the design tokens resolved from
//! them, and the settings an app passes in to choose between them.
//!
//! Pure Rust with no UI-toolkit dependency. There is no settings file: an
//! app builds a [`ThemeSettings`], calls [`resolve`], and pushes the result
//! into its UI (for Slint, onto the `Tokens` global from `origiri-slint`'s
//! `ui/tokens.slint`).
//!
//! Folded in from what used to be the separate Ayame crates
//! (`ayame-colors`, `ayame-config`, the Rust half of `ayame-slint`).
//!
//! The `os` feature adds [`os`], which reads the OS's own light/dark
//! preference and accent color (a registry read on Windows, a D-Bus
//! portal call on Linux, a shell-out on macOS). It's feature-gated, not a
//! separate crate: with the feature off, none of that platform-specific
//! code is compiled and none of its dependencies are pulled in, so this
//! crate stays exactly as pure as before for anyone who doesn't need it.

pub mod palette;
pub mod settings;
mod tokens;

#[cfg(feature = "os")]
pub mod os;

pub use settings::{AnimationSpeed, BorderWidth, CornerRadius, ThemeSettings};
pub use tokens::{
    AnimationTokens, ColorTokens, ResolvedTheme, Rgba, ShapeTokens, SpacingTokens, resolve,
};
