//! Pure-Rust document model and line-breaking engine for rendering mixed
//! text + embedded-element content -- the shared problem behind Cettila's
//! TypedMark block mode, mumeum's `mumeum-text-editor`, and immermemo's
//! `immermemo-editor`, none of which render embedded elements recursively
//! inline (each falls back to a single-line label or a whole-line/whole-
//! block decoration instead). See `origami-richtext`'s README for the
//! Slint-facing half of this pair.
//!
//! No UI-toolkit dependency, same split as `origami-theme`/`origami-panes`.

pub mod layout;
pub mod model;

pub use layout::{Fragment, Line, Measure, layout_block};
pub use model::{Block, BlockKind, ElementId, Inline, Position, StyleId, TextStyle};
