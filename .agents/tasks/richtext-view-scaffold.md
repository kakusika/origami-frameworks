# Scaffold `origiri-richtext` / `origiri-richtext-flow`

Generic Slint view for rendering text mixed with embedded elements
(block + inline, editable), for immermemo and mumeum to build their Tomet
editors on. Design discussed and agreed with the user before this task
started; this file only tracks the scaffolding step, not the full design
rationale.

Crate split (mirrors the `origiri-theme`/`origiri-panes` pure-Rust
convention, plus the `links` + `DEP_*_UI_DIR` pattern `mumeum-text-editor`
already uses for shipping `.slint` source without a `slint_build` step in
the library crate itself):

- `origiri-kit/views/richtext-flow` (`origiri-richtext-flow`): pure Rust,
  no `slint` dependency. Document model (`Block`/`Inline`/atomic
  `Element`/structured `Position`) and the line-breaking engine.
- `origiri-kit/views/richtext` (`origiri-richtext`): ships `ui/flow_view.slint`
  only (no `slint_build` call in this crate -- Slint's generated struct
  types only exist inside whichever crate's own `slint_build::compile()`
  call processes a tree that imports them, so this crate's Rust side stays
  thin; each consuming app writes its own small seam, same as immermemo's
  existing `apps/slint/src/render.rs`).

## Steps

- [x] Create `origiri-kit/views/richtext-flow`: `Cargo.toml`, `src/lib.rs`,
      `src/model.rs`, `src/layout.rs`, `README.md`.
- [x] Create `origiri-kit/views/richtext`: `Cargo.toml` (`links =
      "origiri_richtext"`), `build.rs`, `ui/flow_view.slint`, `src/lib.rs`,
      `README.md`.
- [x] Register both as workspace members + `[workspace.dependencies]` in
      the root `Cargo.toml`.
- [x] Add both to the root `README.md`'s crate list.
- [x] `cargo check -p origiri-richtext-flow -p origiri-richtext` passes.

## Known gaps left for follow-up (not part of this scaffold)

- `layout::layout_block` only emits a single line (no real greedy
  word-wrap / line-breaking yet).
- No edit-operation API (insert/split/delete) on the document model yet --
  only the static tree + `Position` type.
- `ui/flow_view.slint`'s `FlowView` is unverified against a real Slint
  compile (this crate has no `slint_build` step of its own; first real
  syntax check happens when an app imports it).
