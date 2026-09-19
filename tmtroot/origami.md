# Origami: gaps against mature creative-tool UIs

Rough scratch notes, not a spec. This is *not* derived from any stated
roadmap -- it's a gap analysis: what a mature, pane-based creative-tool
UI (Blender primarily, since this app's own shape -- a dockable/
splittable pane system hosting several distinct editor types:
board/canvas, node-graph, link-graph, table, text-editor, explorer, map
-- maps onto Blender's workspace/editor-area model unusually closely)
typically has, checked against what `crates/views/origami/qml/`
currently has. Treat every item below as "plausibly needed eventually,"
not "confirmed to be built next" -- re-check the actual `qml/` tree
before acting on any of it, since it may already exist or the app's
actual needs may never reach some of these.

## widgets/inputs/ -- likely gaps

- **Single boolean toggle / checkbox.** `ToggleGroup.qml` only covers
  an exclusive *group* of options; there's no equivalent for a single
  standalone on/off switch (Blender's checkbox-style toggle buttons,
  used constantly in property panels). Basic enough that its absence
  will probably surface the moment any settings/property UI grows past
  what `SettingsPage.qml`'s existing rows cover.
- **Numeric stepper/scrub field.** Blender's number buttons combine
  click-drag-to-scrub, click-to-type-exact-value, and +/- step arrows
  in one widget -- distinct from a plain `Slider` (`SizeSlider.qml`).
  Any property editing beyond icon-scale-style sliders will likely want
  this.
- **Color swatch / picker button.** Given this app edits visual content
  (board/canvas, node-graph), a color-picking widget seems like a
  near-certain eventual need and there's currently nothing here for it.
- **Search-as-you-type field bound to a filtered list.**
  `CollapsibleTextField.qml` covers the *field* shape (icon + collapsing
  text entry) but not "type here, a list below narrows live" --
  Blender's search boxes (and this app's own `Explorer` view) are
  usually paired with exactly that.

## views/ -- likely gaps

- **Generic tree view** (expandable/collapsible rows, disclosure
  triangle) -- Blender's Outliner is built on this. If `Explorer`'s own
  tree (`ExplorerTree.qml`, in the `explorer` crate, not origami) is
  Explorer-specific today, a reusable version here would be the
  Blender-style move once a second tree-shaped UI shows up anywhere
  else in the app.
- **Generic list view with selection** -- same reasoning, paired with
  the point above.

## templates/ -- likely gaps

- **Full color-picker popup** (swatch trigger + HSV/hex fields), built
  on the widgets/inputs color swatch above.
- **List-with-add/remove/reorder** (Blender's `UIList` pattern: rows
  plus a `+`/`-`/up/down button column) -- plausible for anything
  list-of-items-editable, e.g. a node-graph's layer/group list.
- **Generic confirm/message dialog.** Right now `templates/dialog/`
  only has the very specific `ImagePickerDialog`/`ImagePickerPage`;
  there's no reusable "are you sure?" or simple message-box shape yet.

## regions/ -- likely gaps

- **Toolbar region** -- a persistent icon-button tool palette distinct
  from `HeaderBar.qml` (Blender's tool shelf). `ActionButtonGroup.qml`
  (just added) is a plausible building block for this, but there's no
  region-level container for it yet, the way `regions/header/` /
  `regions/sidebar/` / `regions/statusbar/` exist for their own areas.
- **Tooltip overlay system.** Already a known trouble spot in this app
  (see the "Kirigami ToolTip.visible hardcoded" memory -- Breeze's
  style ignores app-set `ToolTip.visible`), so this is more "known gap
  to eventually formalize as its own origami component" than a guess.
- **Notification/status toast.** Blender surfaces transient
  operator-report messages near the bottom of the window; `StatusBar.
  qml` exists for persistent status but nothing here handles ephemeral
  "action succeeded/failed" messages yet.

## Noted but probably out of scope for now

- Pie menus, curve/gradient-ramp editors, full asset-browser templates
  -- real Blender features, but large/special-purpose enough that
  they're not worth planning around until something in this app
  concretely needs one.
