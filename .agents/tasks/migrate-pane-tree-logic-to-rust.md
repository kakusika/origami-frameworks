# Migrate pane-tree structural logic from QML to Rust

Not started yet -- user wants this done in a future session, this file is
the resumable spec. Read `docs/architecture.md`'s "Pane / workspace
system" section first for the tree shape vocabulary (`split`/`pane`/
`tabs`/`drawer`) before touching anything here.

## Why this file exists

`origami/src/pane_tree.rs` (`PaneTree`) plus the `WorkspaceManager` cxx-qt
object in `origami/src/cxxqt_object.rs` (qinvokables `split_pane`/
`add_tab`/`close_tab`/`set_current_tab`/`move_tab`/`change_pane_type`/
`update_tree_json`) exist but are **dead code** -- confirmed by grepping
every `.qml` file under `cettila` and `origami-frameworks` for
`WorkspaceManager`: zero matches. The actually-running app only uses
`WorkspaceStore` (`load_json`/`save_json`, a dumb JSON-string passthrough
to `cettila-config::workspace`) -- all real tree mutation logic lives in
`origami/qml/pane/PaneView.qml` as plain JS operating on cloned JS object
trees (see that file's own top-of-file doc comment for the shape).

This was discovered while fixing same-orientation nested-split bugs (see
git history around 2026-08-14: `PaneTree::split_pane`/`split_node_rec` in
`pane_tree.rs`, and `requestDrop()`/`insertTab()` in `PaneView.qml`, both
now avoid nesting a `split` inside a same-orientation parent `split`; and
`_restoreNode()`'s `"split"` branch now flattens any such nesting found in
previously-saved data, once, at startup). Those fixes were applied
**twice** (once per implementation) specifically because the Rust side
isn't wired up -- a concrete symptom of the duplication this task would
remove.

## Decision needed before starting

Two real options, not yet chosen:

1. **Finish wiring `WorkspaceManager` up and make QML call into it**
   (this task, described below).
2. **Delete the dead Rust code** and accept QML/JS as the one and only
   implementation.

Don't start (1) without re-confirming with the user this is still wanted
-- if the motivation was just "why does this exist," maybe deletion is
the actual next step instead. This file assumes (1) since that's what was
asked for, but say so explicitly if picking (2) instead when this is
picked back up.

## What can and can't move

- **Can move**: tree *shape* -- node type, id, orientation, `size`
  fractions, `currentIndex`, `viewType` string, `props` (serializable
  per-pane state via `paneSerialize()`/`paneRestore()`), drawer's
  `expanded`/`overlayWidth`/`overlayHeight`. All plain data, exactly what
  `PaneNode`/`SplitChild`/`GroupChild` in `pane_tree.rs` already model.
- **Cannot move**: a pane's live `component`/`item` (QtQuick `Item`
  instances, created via `component.createObject()` in
  `materialize()`/`_itemCache`, PaneView.qml lines ~127-208). These are
  UI-thread QQuickItem pointers tied to the QQmlEngine; Rust has no clean
  way to own them (cxx-qt could expose opaque `QObject*`/`QVariant`
  handles, but there's no upside to doing so -- rendering code needs them
  as real QML items, not round-tripped through Rust). `materialize()`/
  `resolveActivePane()`/`beginDrag()`/`endDrag()`/`toggleMaximize()` stay
  QML-side regardless of how this task goes.

So the end state is a **hybrid**, not a full migration: Rust becomes the
source of truth for tree *shape* (serialized as `tree_json`, same
QString-property pattern `WorkspaceManager` already has), QML keeps an
id-keyed `_itemCache`-style side table for live items, and every
structural mutation QML currently does in-place on a cloned JS tree
instead becomes a qinvokable call into `WorkspaceManager`, followed by
QML re-deriving its render tree from the newly-updated `tree_json` (via
something like today's `_restoreNode()`, matching by id against the
existing `_itemCache` to reuse already-materialized items rather than
recreating them).

## API gap (audited 2026-08-14)

QML-side structural mutation functions in `PaneView.qml`, and their
Rust-side (`pane_tree.rs`/`cxxqt_object.rs`) status:

| QML function | Rust equivalent | Status |
|---|---|---|
| `changePaneType` | `change_pane_type` | exists |
| `addPaneToTabs` | `add_tab` | exists (check semantics match) |
| `setCurrentTab` | `set_current_tab` | exists |
| `closeTab` | `close_tab` | exists (check empty/last-child semantics match `_isGroupType`'s "never collapse tabs/drawer" rule) |
| move-tab-within/across groups (part of `requestDrop`) | `move_tab` | exists, but only covers group-to-group; `requestDrop`'s full zone logic (below) doesn't |
| `requestDrop` (create split/tabs/drawer from a drag, all zones: center/left/right/top/bottom/drawer-top/drawer-bottom, plus same-orientation merge, plus source-side collapse/renormalize) | -- | **missing**, this is the biggest one |
| `extractTab` / `insertTab` (cross-`PaneView`-instance drag, e.g. sidebar <-> main area) | -- | **missing** |
| `setSplitSizes` | -- | **missing** (drag-resize write-back, see `PaneSplit.qml`'s own comment on why it writes through the controller rather than the node directly) |
| `setDrawerExpanded` / `setDrawerOrientation` / `setDrawerOverlayWidth` / `setDrawerOverlayHeight` | -- | **missing** |
| `setGroupType` (tabs <-> drawer conversion) / `canConvertDrawerToTabs` | -- | **missing** |
| `detachPane` / `closeAllTabs` / `closeGroup` | -- | **missing** |
| `_collapseInto` / `_removeStandalonePane` / `_renormalizeSizes` (split-collapses-to-one-child cleanup, used by several of the above) | -- | **missing**, but small and shared -- port this early, several ops above depend on it |
| `_restoreNode`'s same-orientation-nesting flatten (2026-08-14 addition) | -- | **missing on the Rust load path** -- if `PaneTree::from_json`/`load_workspace` become the real load path, port this flatten there too, or the fix silently regresses for whichever path stops being used |
| `serializeTree` / `_restoreNode` | `serialize_json` / `from_json` | shape mostly exists, but `_restoreNode` also does componentRegistry lookup + drops unknown viewTypes + prunes empty splits -- Rust's `from_json` doesn't validate against a component registry (it can't, that's QML-side knowledge), so QML still needs *some* post-load pass even in the target end state |

## Suggested step order

- [x] Re-confirm the wire-up-vs-delete decision above with the user
      before writing code. -- Confirmed 2026-08-14: proceeding with
      wiring up `WorkspaceManager` (option 1).
- [x] Port `_collapseInto`/`_removeStandalonePane`/`_renormalizeSizes`
      equivalents into `pane_tree.rs` first -- small, shared by several
      of the missing ops below. -- Done 2026-08-14: added
      `collapse_into`/`renormalize_sizes`/`remove_standalone_node` (free
      functions) plus `PaneTree::remove_standalone(target_id)` as the
      public entry point, with 4 new unit tests
      (`test_remove_standalone_*`). `cargo test -p origami` passes
      (10/10, via `direnv exec .`).

      Note for the next step (`requestDrop`): `PaneNode::Split`'s `id`
      field is `Option<i32>` and `split_pane`/`split_node_rec` always
      construct new splits with `id: None` -- unlike QML, where every
      node (including "split") gets a real id via `_genId()`. This
      doesn't block `remove_standalone` (it just preserves `None`
      through a collapse), but `setSplitSizes` (also not yet ported)
      needs to find a *nested* split by id the same way QML's
      `_find()`/`PaneSplit.qml` do, which a permanently-`None` id can't
      support. Decide when porting `requestDrop`/`setSplitSizes` whether
      to make `Split.id` a plain `i32` assigned via `gen_id()` (mirrors
      QML exactly) -- flagging now since `requestDrop` is what actually
      creates most new split nodes.
- [ ] Port `requestDrop`'s full zone logic (the big one) into
      `PaneTree`, including the 2026-08-14 same-orientation-merge
      behavior `split_pane` already has -- reuse rather than
      reimplementing it.
- [ ] Port `setSplitSizes`, `setDrawerExpanded`/`Orientation`/
      `OverlayWidth`/`OverlayHeight`, `setGroupType`,
      `detachPane`/`closeAllTabs`/`closeGroup`, `extractTab`/`insertTab`.
- [ ] Decide how QML re-derives its render tree after a Rust-side
      mutation without discarding/recreating already-materialized
      `item`s -- likely an id-keyed merge against the existing
      `_itemCache`, not a full `_restoreNode`-style rebuild each time.
- [ ] Switch `main.qml`/`PaneView.qml` off `WorkspaceStore` and onto
      `WorkspaceManager` for load/save, once the above is at parity.
- [ ] Port the same-orientation nesting flatten (currently only in
      `_restoreNode`) to whichever load path (`from_json`/
      `load_workspace`) actually ends up used.
- [ ] Add Rust unit tests per ported operation (pattern: see
      `pane_tree.rs`'s existing `#[cfg(test)] mod tests`).
- [ ] `cargo test -p origami` (needs `direnv exec .` prefix or a `nix
      develop` shell -- plain `cargo test` fails with a Qt
      `QuickControls2` prl-path panic outside that environment, confirmed
      2026-08-14).
- [ ] Delete now-dead QML mutation functions once their Rust
      equivalents are live and QML has been switched over -- don't leave
      both implementations around "just in case."
- [ ] Update `docs/architecture.md`'s "Pane / workspace system" section
      to describe the new split (Rust owns shape, QML owns live items)
      once done.
