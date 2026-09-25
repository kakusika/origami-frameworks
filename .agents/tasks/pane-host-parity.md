# Pane system parity: QML PaneView/PaneDrawer vs origami-panes + pane_host.slint

Goal: find what the old QML pane system (`origami/qml/pane/core/PaneView.qml`,
`groups/PaneDrawer.qml`, 2,760 lines) did that the Slint side
(`origami-kit/panes` + `origami-slint/ui/pane_host.slint`) does not yet.

Method: listed every function/signal/property of the two QML files and
looked for the counterpart by name and behavior in `origami-panes`
(`pane_tree.rs`, `drop.rs`, `layout.rs`, `outline.rs`), in `pane_host.slint`,
and in mumeum's `apps/desktop/src/panes.rs` (the only real consumer).
"Present" means the code exists; NONE of the interactive parts (drag/drop,
drawer overlay, maximize, detach) have been exercised by hand yet.

## Status

- [x] Inventory of QML functions/properties
- [x] Match against Rust lib / pane_host / mumeum
- [x] G1 part 1: `origami-panes::edit` (`PaneTree::{set,toggle}_drawer_expanded`,
      `can_convert_drawer_to_tabs`, `convert_group`, `close_all_tabs`,
      `close_group`, `prune_empty_groups(keep)`, `divider_baseline`,
      `resize_pair`) + `PaneNode::{find, tab_index}`, 15 new tests; gallery
      switched to them (its `resize_pair` copy and drawer-toggle copies are gone)
- [ ] G1 part 2: switch mumeum (`apps/desktop/src/panes.rs`, `app_state.rs`) to
      the library API and drop its copies. Needs this repo committed and
      pushed first (mumeum depends on it by git). Note mumeum's `convert_group`
      had no "drawer children must all be panes" check; the library adds it.
      mumeum passes `&[EDITOR_GROUP_ID]` to `prune_empty_groups`.
- [ ] Decide which gaps to close and in what order (see "Gaps")
- [ ] Manual pass over the present-but-unexercised interactions

## Present in origami-panes

| QML (PaneView) | Rust |
|---|---|
| restoreTree / serializeTree | `PaneTree::from_json` / `serialize_json` |
| _genId | `PaneTree::gen_id` |
| changePaneType | `change_pane_type` |
| addPaneToTabs | `add_tab` |
| setCurrentTab | `set_current_tab` |
| closeTab, _removePane, _collapseInto, _renormalizeSizes | `close_tab`, `remove_standalone` (collapse + size renormalize are tested) |
| requestDropAtIndex / insertTabAtIndex | `drop::apply_index_drop` |
| requestDrop / extractTab / insertTab | `drop::apply_drop`, `PaneTree::move_tab`, `split_pane`, `split_root` |
| drop-zone geometry (PaneDropOverlay) | `drop::compute_zone`, `highlight_rect`, `find_target_leaf`, `find_tab_strip_target`, `tab_insertion_line_rect` |
| layout of split/tabs/drawer/maximize | `layout::layout_tree` |
| PaneManager tree data | `outline::outline` (new) |

## Present in pane_host.slint (code exists, not exercised)

Dividers with drag-resize, per-leaf header (grip, type switcher, menu,
maximize, detach, close), tab strip with drag and add button, cross-group tab
drag, group frame, drawer rail with click-to-open overlay, convert-group
button, view-type picker hook (`request-picker`).

## Gaps

### G1. Logic that lives in consumers instead of origami-panes (duplicated)

mumeum `apps/desktop/src/panes.rs` and the gallery's `main.rs` each carry
their own copy of tree operations the QML `PaneView` owned:

| QML | mumeum | gallery |
|---|---|---|
| setDrawerExpanded | `toggle_drawer_expanded` | inline in `on_toggle_drawer` |
| setGroupType, canConvertDrawerToTabs | `convert_group` | (not handled) |
| setSplitSizes (divider drag) | `resize_pair` | `resize_pair` (copy) |
| empty-group pruning (README "known gap") | `prune_empty_groups` | (not handled) |
| find by id / tab index | `find_node`, `find_tab_index` | (uses `find_node_mut`) |
| closeTab / closeAllTabs / closeGroup / detachPane | `close_leaf`, `detach_leaf` in app_state | (not handled) |

Fix: move these into `origami-panes` (with the tests mumeum already has for
`convert_group`, `prune_empty_groups`) and make both consumers call them.
`closeAllTabs` and `closeGroup` have no Rust counterpart anywhere yet
(`remove_standalone` may cover `closeGroup` for a group id; verify).

### G2. Not ported at all

- `insertPaneAtSplitBoundary` (insert a new pane at a split boundary, UI: the
  "+" between panes). `split_pane`/`split_root` cover edge drops only.
- Drawer orientation (`setDrawerOrientation`, `_toggleOrientation`, node
  field `orientation`): Rust `PaneNode::Drawer` has no such field; layout
  forces the rail perpendicular to the parent split. Decide: drop the
  feature or add the field (serde-compatible, `#[serde(default)]`).
- Drawer overlay size persistence (`overlayWidth`/`overlayHeight`,
  `setDrawerOverlayWidth/Height`) and the overlay's edge-grab resize and
  flip-when-overflowing (`_overlayWouldOverflow`, `_flip`, `grabMargin`).
  pane_host opens an overlay but has no resize handles or size state.
- Drag reorder inside a drawer's own tab list with insertion line
  (PaneDrawer `updateIndex`, both orientations). pane_host only has the
  tab-strip version.
- `framed` drawers, `_groupMenuItems` (drawer's group menu).
- Toolbar panes (`isToolbarPane`, `PaneToolbar`, `fixedSizePx`): layout.rs
  states "no toolbar node kind is ported".
- `dragActive`, `layoutLocked`, `resizeLocked` controller flags (lock the
  layout while dragging / when a host wants it frozen).
- Icon registry / component registry / `viewTypeRegistry` +
  `viewTypeCategories` (picker contents): the picker is an inert
  placeholder in mumeum; origami's `view_type_picker.slint` takes rows but
  nothing supplies categories.

### G3. Intentionally not applicable

`materialize`, `_itemCache`, `resolveActivePane`, `beginDrag/endDrag`
with proxy items and `dragLayer`: QML item lifetime management. Slint
re-renders from the flat cell list, and drag proxies are drawn by pane_host.

## Suggested order

1. G1 (pure Rust, testable, removes duplication, unblocks a clean mumeum).
2. Manual pass over pane_host interactions (drag/drop, overlay, maximize,
   detach) so G2 decisions rest on what actually works.
3. G2 in this order: drawer overlay resize/persist, drawer tab reorder,
   boundary insert, drawer orientation (or drop it), toolbar panes.
