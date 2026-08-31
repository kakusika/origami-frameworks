// This crate's content is QML (see build.rs) -- SettingsKit has no Rust
// bridge objects of its own. MARKER exists only so a real reference to
// this crate survives cargo's dead-code elimination: without one, nothing
// pulls this rlib into the final link, and its QML plugin (cxx-qt-build's
// static initializer) never registers -- see ayame-stylekit's own lib.rs
// (ayame/crates/stylekit/src/lib.rs) for the identical pattern/reasoning,
// and ayame-icons' README for the same issue's original writeup.
#[used]
pub static MARKER: &str = "origami-view-settings";
