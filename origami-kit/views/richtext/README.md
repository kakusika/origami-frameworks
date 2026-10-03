# origami-richtext

Slint-facing half of the text + embedded-element renderer
(`origami-richtext-flow` has the pure document model and line-breaking
engine). Ships `ui/flow_view.slint` -- a generic `FlowView` component that
renders lines of positioned fragments, embedding real Slint components for
element fragments via `slint::ComponentFactory`/`ComponentContainer`
rather than flattening them to a label or an image.

## Why this crate's Rust side is thin

Slint's generated Rust types for a `.slint` `export struct` only exist
inside whichever crate's own `slint_build::compile()` /
`slint::include_modules!()` call processes a tree that imports that
struct -- this crate does not call either. If it compiled its own copy of
`flow_view.slint` to get `RichTextFragment`/`RichTextLine` as real Rust
types, those would be a *different* Rust type from the ones the consuming
app's own compile produces, even though they look identical, so values
could not be passed between them. (immermemo's own `apps/slint/src/
render.rs` doc comment describes the same constraint for its
`RenderedBlock` type.)

So this crate exposes `ui/` only, via the `links` key as
`DEP_ORIGAMI_RICHTEXT_UI_DIR` -- the same mechanism `mumeum-text-editor`
already uses to ship `ui/blocks_view.slint` without its own `slint_build`
step.

## Caller's responsibilities

- Add this crate's `ui/` directory as a library path (e.g. `@richtext`) in
  the app's own `build.rs`, the same way `mumeum`'s `apps/desktop/build.rs`
  wires in `mumeum-text-editor`'s `DEP_MUMEUM_TEXT_EDITOR_UI_DIR`.
- Write a small seam module converting `origami-richtext-flow::Line`/
  `Fragment` values into the app's own generated `RichTextLine`/
  `RichTextFragment` -- mechanical field copying, the same shape
  immermemo's existing `render.rs` already has for its simpler
  `RenderedBlock` case.
- Build and register a `slint::ComponentFactory` per element kind the app
  cares about (its own vocabulary -- see `origami-richtext-flow`'s README
  for why this isn't shared across apps), and resolve an `ElementId` to one
  when constructing each `RichTextFragment`.
- Font-metrics text measurement for `origami-richtext-flow`'s `Measure`
  trait: use an offscreen `Text` element's `preferred-width`, the technique
  mumeum's `LineNumberGutter` already uses for line-height.

## Known gaps

- `flow_view.slint` has not been exercised by a real Slint compile yet (no
  consuming app wires it in so far).
- No cursor/selection rendering or input handling in `FlowView` itself yet
  -- `origami-richtext-flow`'s `Position` type exists, but nothing here
  turns it into a drawn caret or routes key/IME events into an edit yet.
