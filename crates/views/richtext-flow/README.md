# origami-richtext-flow

Pure Rust, no UI-toolkit dependency, same convention as `origami-theme`/
`origami-panes`: a document model for text mixed with embedded elements
(block + inline), and the line-breaking engine that lays it out.

## Background

immermemo, mumeum, and Cettila (the project this ecosystem originated
from) have each independently built a "render Tomet/TypedMark structure in
a GUI" feature, and all three stop short of the same thing: rendering an
inline element recursively, as a real embedded widget, in the middle of a
line of text. Cettila's own block mode renders typed elements/links as a
single-line fallback label ("not recursively rendered", its README's own
words); mumeum's `mumeum-text-editor` copied that same block mode and has
the same limitation; immermemo's `immermemo-editor` takes a different
approach (classifying whole lines into chips/badges) that never mixes text
and an element within one line either. This crate exists to do the thing
all three have punted on.

## What it provides

- `model`: `Block`/`Inline` -- a block holds ordered inline content, where
  each unit is either a styled text run or an atomic embedded element
  (`Inline::Element`, identified only by an opaque `ElementId`). Elements
  are indivisible: a `Position` can point before or after one, never
  inside it.
- `layout`: `layout_block` breaks a block's inline content into `Line`s of
  positioned `Fragment`s, given a `Measure` implementation that reports
  text and element widths. **Only a single-line placeholder today** -- see
  `.agents/tasks/richtext-view-scaffold.md` in the workspace root for the
  real word-wrap work still to do.

## Caller's responsibilities

- Building a `Block` tree from its own AST (Tomet or otherwise) is outside
  this crate. Each app owns that mapping, since each app's element
  vocabulary differs (e.g. immermemo's `@mobile.conflict` is not something
  mumeum needs to know about).
- Implementing `Measure` against real font metrics and real widget
  intrinsic sizes is the caller's job; see `origami-richtext`'s README for
  how the Slint-facing half does this.
- No edit-operation API yet (insert/split/delete on the tree) -- only the
  static tree and the `Position` type to address into it.
