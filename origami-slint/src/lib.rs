//! Slint-side widgets and build-time wiring (`ui/*.slint`, `build.rs`'s
//! `UI_DIR`). The pane tree/layout/drag-drop logic itself lives in
//! `origami-panes` now (toolkit-independent, no Slint dependency) --
//! re-exported below so existing `origami_slint::{pane_tree,layout,drop}`
//! call sites don't need to change.

pub use origami_panes::drop;
pub use origami_panes::edit;
pub use origami_panes::layout;
pub use origami_panes::outline;
pub use origami_panes::pane_tree;
