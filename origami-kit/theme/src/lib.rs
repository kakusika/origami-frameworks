//! Origami's theme: named color palettes, the design tokens resolved from
//! them, and the settings an app passes in to choose between them.
//!
//! Pure Rust with no UI-toolkit dependency. There is no settings file: an
//! app builds a [`ThemeSettings`], calls [`resolve`], and pushes the result
//! into its UI (for Slint, onto the `Tokens` global from `origami-slint`'s
//! `ui/tokens.slint`).
//!
//! Folded in from what used to be the separate Ayame crates
//! (`ayame-colors`, `ayame-config`, the Rust half of `ayame-slint`).

pub mod palette;
pub mod settings;
mod tokens;

pub use settings::{AnimationSpeed, BorderWidth, CornerRadius, ThemeSettings};
pub use tokens::{
    AnimationTokens, ColorTokens, ResolvedTheme, Rgba, ShapeTokens, SpacingTokens, resolve,
};
