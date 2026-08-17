# Async pane materialization (fix UI freeze on first pane add)

## Problem

Adding a pane of a view type that hasn't been opened yet in this session
freezes the whole app briefly. Root cause: `PaneView.qml::materialize()`
(`origami/qml/pane/PaneView.qml`, ~line 196) calls
`pane.component.createObject(root)` synchronously. `createObject()` blocks
the QML/UI thread until the whole component subtree is built; for a heavy
view (Vulkan-backed 3D graph view, etc.) that's a visible freeze. Reopening
an already-materialized pane is fast because `_itemCache` (keyed by pane
id) skips re-creation -- matches the reported "only on *new* add" symptom.

Chosen approach (user-selected): make `materialize()` itself asynchronous
(via `Component.incubateObject()`), shared by every view, rather than
special-casing only the known-heavy view types.

## Before starting: profile first

Confirm which view(s) actually cause the freeze and *where* the cost sits
(QML tree construction, which incubation can chunk across frames, vs. a
single expensive synchronous call inside that view's own
`Component.onCompleted`, e.g. a renderer/GPU init, which incubation does
NOT help with -- it only staggers object-graph construction, not a single
handler's own body). Use the existing offscreen + console.log + journalctl
technique (see project memory `reference_qml_console_log_journald`) rather
than guessing. If the cost turns out to be inside one view's own
`onCompleted`, that view needs its own fix (e.g. deferring its heavy init
to after first paint) *in addition to* this change, not instead of it.

## Call sites found (see conversation for full analysis)

All in `origami-frameworks/origami/qml/pane/` unless noted:

1. `PaneLeaf.qml:140` (`_updateContent()`) -- reparents `pane.item` into
   `contentArea` to actually show it. Straightforward: show a placeholder
   while pending, swap in once ready.
2. `PaneHeader.qml:70` (`readonly property var _activeItem`) -- reactive
   binding; feeds `_hasError` and `_effectiveMenus`. **Problem**: a plain
   QML binding only re-evaluates when a property *it reads* changes --
   swapping `materialize()`'s return to "null now, arrives later via
   incubator" does NOT automatically re-trigger this binding. Needs a
   notifying property (e.g. a `controller`-owned incrementing counter,
   bumped whenever an incubation completes) referenced inside this
   binding expression, purely to force re-evaluation.
3. `PaneManagerRow.qml:127` (`_moveToNewWindow()`) -- imperative one-shot:
   `var item = controller.materialize(node); if (!item) return;` then uses
   `item` immediately to open a new `PaneWindow`. Needs to become
   genuinely async (wait for a completion signal before opening the
   window) -- though in practice this only fires from a menu on an
   *already-rendered* pane, so it will almost always hit the `_itemCache`
   fast path already; low real-world risk, but the code path still needs
   to handle the pending case correctly rather than silently no-op'ing.
4. `cettila/crates/views/properties/qml/Properties.qml:60`
   (`resolvedPane`, via `resolveActivePane()`) -- same reactive-rebind
   problem as #2. Downstream consumers already null-check
   (`resolvedPane &&`), so should degrade gracefully once wired to the
   same completion-notifying property.

Also: `PaneWindow.qml:43` has its OWN, separate synchronous
`paneComponent.createObject(contentHost)` (used by "open in new window"
for a pane that doesn't exist yet). Same freeze risk, same fix pattern,
but a distinct code path from `materialize()` -- needs its own
incubation conversion to actually close this gap everywhere "a new pane
gets created" (not just the main add-to-tree path).

## Design sketch

- `materialize(pane)` keeps its synchronous signature and the
  `_itemCache` fast path unchanged (already-materialized panes are
  unaffected).
- On a cache miss: start `pane.component.incubateObject(root, {},
  Qt.Asynchronous)`, track it in a new `_pendingIncubators` map keyed by
  pane id (guards against kicking off a second incubation if
  `materialize()` gets called again for the same pane before the first
  finishes -- e.g. `_activeItem`'s binding and `_updateContent()` can
  both call it in the same tick). Return `null` for this call.
- Add `signal paneMaterialized(int paneId, var item)` on the controller,
  and a plain incrementing `property int _materializeVersion: 0`. The
  incubator's `onStatusChanged` (on `Component.Ready`): store into
  `_itemCache`/`pane.item`, bump `_materializeVersion`, emit
  `paneMaterialized`. `Component.Error` needs a defined fallback too
  (surface via `ErrorBus`/`ToastBus`, not just silently stay null forever).
- Every reactive call site (#2, #4) adds a read of
  `controller._materializeVersion` inside its binding expression (even if
  otherwise unused) so QML's dependency tracking re-evaluates it once
  incubation completes.
- `PaneLeaf._updateContent()` (#1): show a lightweight placeholder in
  `contentArea` while pending; listen for `paneMaterialized` (filtered to
  its own currently-displayed pane id) to swap the real item in.
- `PaneManagerRow._moveToNewWindow()` (#3): if `materialize()` returns
  null, listen for `paneMaterialized` for that pane id once, then proceed
  with the existing detach+PaneWindow logic.
- `PaneWindow.qml:43`: same incubation conversion for its own
  `paneComponent.createObject()`, with its own loading placeholder while
  pending.

## Steps

- [ ] Step 0: Profile (journalctl/console.log, offscreen) to confirm
      where the cost actually sits, per "Before starting" above.
- [ ] Step 1: Add `_pendingIncubators`, `paneMaterialized` signal,
      `_materializeVersion` counter, and convert `materialize()` itself
      to incubation (`PaneView.qml`).
- [ ] Step 2: `PaneLeaf.qml` -- placeholder while pending + swap-in on
      `paneMaterialized`.
- [ ] Step 3: `PaneHeader.qml` -- wire `_activeItem` (and anything
      downstream, `_hasError`/`_effectiveMenus`) to `_materializeVersion`.
- [ ] Step 4: `PaneManagerRow.qml` -- make `_moveToNewWindow()` wait for
      completion instead of bailing on a null item.
- [ ] Step 5: `cettila/crates/views/properties/qml/Properties.qml` --
      wire `resolvedPane` to `_materializeVersion` the same way.
- [ ] Step 6: `PaneWindow.qml` -- convert its own separate
      `paneComponent.createObject()` to incubation too.
- [ ] Step 7: `cargo check` in both repos after each step (origami-frameworks
      standalone + `cargo check -p cettila-qml` from cettila, which is
      path-patched to this checkout).
- [ ] Step 8: Manual smoke test by the user -- GUI click-testing is off
      limits for the agent (AGENTS.md), so this step cannot be
      self-verified; flag every changed interaction explicitly for the
      user to click-test (add new pane of a never-opened view type, tab
      switching, "move to new window", "open in new window", Properties'
      workspace tab).
- [ ] Step 9: Delete this task file once done and confirmed working.
