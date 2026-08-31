//! Pane-docking tree state, layout math, and drag/drop-to-split logic for
//! Slint-based apps -- the Slint-side counterpart to `origami`'s own QML
//! pane system (`origami/qml/pane/{core,groups}`), Qt-free by design (only
//! `serde`/`serde_json`, no `cxx-qt`) so any Slint app in this workspace
//! family can depend on it without pulling in a Qt toolchain.
//!
//! Originally prototyped as a hand-copied, "keep in sync manually" module
//! set inside `cettila`'s `desktop-slint` app (see that repo's own git
//! history for `apps/desktop-slint/src/{pane_tree,layout,drop}.rs`); moved
//! here so it's a real shared dependency instead. `layout.rs`'s design
//! rationale (why a flat cell list instead of recursive component nesting)
//! and each module's QML-port citations are preserved in their own doc
//! comments below.

pub mod drop;
pub mod layout;
pub mod pane_tree;
