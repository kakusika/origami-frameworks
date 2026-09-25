//! Pane-docking tree state, layout math, and drag/drop-to-split logic --
//! split/tabs/drawer add/close/move/resize, edge-zone drag-to-split,
//! tab-strip reorder, maximize/un-maximize, drawer collapse/expand.
//! Ported from `origami`'s own QML pane system (`origami/qml/pane/
//! {core,groups}`); each function's doc comment cites its specific QML
//! counterpart.
//!
//! Toolkit-independent by design (only `serde`/`serde_json`, no UI
//! framework dependency at all) -- originally lived inside `origami-slint`
//! (see that crate's own history) but doesn't actually depend on Slint,
//! so it moved to `origami-kit` once the QML/Qt-based `origami` pane
//! system was slated for removal: with only one UI backend left, this is
//! core framework infrastructure, not something scoped to a specific
//! backend crate. `origami-slint` re-exports these modules for source
//! compatibility with existing consumers.

pub mod drop;
pub mod edit;
pub mod layout;
pub mod outline;
pub mod pane_tree;
