//! Slint-facing half of the text + embedded-element renderer.
//! `origami-richtext-flow` has the pure document model and line-breaking
//! engine; this crate's own Rust surface is intentionally thin.
//!
//! It ships `ui/flow_view.slint` only -- there is no `slint_build` call in
//! this crate. Slint's generated struct types (e.g. for a `.slint`
//! `export struct`) only become real Rust types inside whichever crate's
//! own `slint_build::compile()`/`slint::include_modules!()` call compiles a
//! tree that imports them; a library crate compiling its own copy would
//! not produce the same Rust type the consuming app needs. So the `ui/`
//! directory is exposed via the `links` key as `DEP_ORIGAMI_RICHTEXT_UI_DIR`
//! (the same mechanism `mumeum-text-editor` uses) for the app's own
//! `build.rs` to add as a library path, and each app writes its own small
//! seam converting `origami-richtext-flow`'s pure `Line`/`Fragment` values
//! into its own generated `RichTextLine`/`RichTextFragment` -- the same
//! shape immermemo's existing `apps/slint/src/render.rs` already has for
//! its own, simpler case.
//!
//! Per-element-kind rendering (what widget a given `ElementId` becomes, via
//! `slint::ComponentFactory`) is also necessarily per-app code for the same
//! reason, which lines up with each app owning its own element vocabulary
//! anyway (see `origami-richtext-flow`'s README).

pub use origami_richtext_flow as flow;
