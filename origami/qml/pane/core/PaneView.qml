import QtQuick
import la.cettila.Origami 1.0 as Origami

// Root of the generic pane system.
//
// Layout is a recursive tree of four node kinds:
//   - "split": has an orientation ("horizontal"|"vertical") and an array
//     of {size, node} children, shown side by side.
//   - "pane": a single view (id, title, component, viewType, item, props).
//     A standalone pane is just a plain child of a split (or the whole
//     tree) -- it is not "inside a group" of any kind.
//   - "tabs": holds pane children (as {node} entries -- see below) plus a
//     currentIndex, and is what actually gets a tab strip (PaneTabs.qml/
//     PaneTabBar.qml) so the user can switch which child is shown. A
//     "tabs" node only ever exists because the user explicitly combined
//     two panes (dragging one pane onto another, see requestDrop()) --
//     it's never the default shape for otherwise-unrelated views. Unlike
//     "split", closing tabs back down to one (or zero) does NOT collapse
//     it back into a lone "pane" node or prune it away -- see
//     _isGroupType()'s comment for why groups are kept around regardless
//     of child count; PaneLeaf.qml shows an explicit empty-state message
//     in the zero-child case.
//   - "drawer": same {node} children array as "tabs" (a vertical rail of
//     icon tabs, PaneDrawer.qml) plus a currentIndex, but additionally
//     carries an `expanded` flag covering the whole group at once --
//     collapsing it hides the active child's content, which "tabs" has
//     no equivalent for. Collapsed, clicking a tab shows that child's
//     content in a floating overlay instead of switching inline. Created
//     the same way "tabs"/"split" are (dragging a pane onto another's
//     dedicated drawer-top/drawer-bottom drop zone -- see
//     PaneDropOverlay.qml). Same as "tabs", never collapses/prunes away
//     for running low on children.
//
// A "tabs" node's children are wrapped as {node: pane} rather than being
// bare pane objects, deliberately mirroring "split"'s {size, node} shape
// even though there's no per-child "size" here (nothing to individually
// resize when only one child is shown at a time) -- it keeps the two
// child-array shapes consistent, and leaves room to attach other
// per-child, group-membership-specific data later (e.g. pinning, a
// manual order) without another shape migration.
//
// Mutating the JS objects in place doesn't fire QML's property-change
// notifications, so every function that changes the tree builds a cloned
// tree and reassigns it to root.tree. Descendant PaneNode/PaneSplit/
// PaneLeaf instances re-evaluate through their node property reassignment.
//
// A pane's content (the Item created from its component) is the same
// object across clones (only the reference is copied). Because of that,
// when a clone makes an old PaneLeaf get destroyed, it evacuates its
// currently-shown Item to a safe place (dragLayer) first (see
// PaneLeaf.qml) rather than letting it get destroyed alongside the leaf.
//
// For persistence (serializeTree/restoreTree; the caller, main.qml's
// WorkspaceStore, saves/restores this as JSON), each pane carries a
// viewType string alongside component/item. component/item are live
// objects that can't be turned into JSON, so only the viewType string is
// saved, and restoring looks it back up through componentRegistry
// (viewType string -> Component, set by main.qml). Each serialized node's
// own fields are written type-first, structural fields next, and
// children (if any) last -- see _serializeNode -- so the saved YAML
// reads top-down instead of alphabetized (that requires
// cettila-config's serde_json to be built with "preserve_order"; see
// that crate's Cargo.toml).
//
// Each view may optionally implement paneSerialize()/paneRestore(props);
// if it does, they're used to read/write the persisted property bag
// (props) -- e.g. GraphView.qml's CollapsiblePanel open/closed state.
// Views that don't implement them just pass through with props: {}.
Item {
    id: root

    // Initial panes: [{title, component, viewType}, ...]. The caller
    // (main.qml) sets this before Component.onCompleted. Ignored if
    // initialTree is set (that takes priority).
    property var initialTabs: []

    // A plain tree previously produced by serializeTree(), passed to
    // restoreTree() (or null). If set, the tree is restored from this
    // instead of being built from initialTabs.
    property var initialTree: null

    // viewType string -> Component map. Used by restoreTree() to look up
    // the Component to instantiate for a saved viewType. Set by main.qml
    // alongside initialTree.
    property var componentRegistry: ({})

    // viewType string -> icon name map. PaneHeader.qml uses this to show
    // the active pane's own icon in its top-left corner (same lookup
    // pattern as componentRegistry).
    property var iconRegistry: ({})

    // Every selectable view type, as [{viewType, title, icon, category}, ...].
    // Set by main.qml alongside componentRegistry/iconRegistry (same source
    // list, just kept as an array here since PaneHeader.qml needs to list
    // them in menu order rather than look one up by key). Used to populate
    // the pane header's view-type dropdown (see PaneHeader.qml) and by
    // changePaneType() below to resolve the Component for a chosen type.
    property var viewTypeRegistry: []

    // viewTypeRegistry above, grouped by category:
    // [{category, items: [{viewType, title, icon}, ...]}, ...]. Also set by
    // main.qml (see its own _viewTypeCategories comment for the bucketing/
    // ordering). Used by PaneHeader.qml's type-switcher and
    // PaneTabBar.qml's new-tab menu to nest view types under a category
    // submenu rather than listing all of them flat.
    property var viewTypeCategories: []

    property var tree: null

    property int _nextId: 1
    function _genId() {
        return root._nextId++;
    }

    // id -> Item cache backing materialize(), keyed by the pane's stable id
    // rather than trusting pane.item on whichever "pane" object happens to
    // be passed in. Necessary because a "pane" node's id survives tree
    // clones (_cloneNode), but distinct call sites can end up holding
    // distinct (non-===) JS object copies of what's logically the same
    // pane at the same instant -- e.g. PaneHeader.qml's _effectiveMenus
    // eagerly calls materialize() on its own node/_activeTab chain, while
    // PaneLeaf._updateContent() calls it on its own separately-derived
    // pane list; relying on pane.item alone let each such caller create
    // its own Item, leaving one materialized-but-never-reparented orphan
    // that any interactive state on it (e.g. Explorer's paneHeaderMenus
    // toggling its own viewMode) silently applied to nothing visible.
    property var _itemCache: ({})

    function restoreTree(savedTree) {
        var restored = savedTree ? root._restoreNode(savedTree) : null;
        if (restored) {
            root.tree = restored;
            return true;
        }
        return false;
    }

    onInitialTreeChanged: {
        if (root.initialTree) {
            root.restoreTree(root.initialTree);
        }
    }

    Component.onCompleted: {
        if (root.restoreTree(root.initialTree)) {
            return;
        }
        // Each initialTabs entry starts out as its own standalone pane,
        // not bundled together as children of one shared "tabs" node: a
        // group of tabs is something the user forms explicitly (see
        // requestDrop()), not something unrelated default views should
        // start pre-joined into.
        var panes = root.initialTabs.map(function (spec) {
            return {
                type: "pane",
                id: root._genId(),
                title: spec.title,
                component: spec.component,
                viewType: spec.viewType,
                item: null,
                props: null
            };
        });
        if (panes.length === 1) {
            root.tree = panes[0];
            return;
        }
        var children = panes.map(function (pane) {
            return {
                size: 1 / panes.length,
                node: pane
            };
        });
        root.tree = {
            type: "split",
            id: root._genId(),
            orientation: "horizontal",
            children: children
        };
    }

    // Lazily creates an Item from a pane's component, keyed by pane.id in
    // _itemCache (see its comment for why id rather than the pane object
    // itself is the cache key) and mirrored onto pane.item for callers that
    // read it directly (e.g. PaneLeaf's "else" branch for an inactive tab).
    // A restored pane (pane.props holds saved properties) has
    // item.paneRestore() applied exactly once, right after creation.
    //
    // Starts life hidden and parented to root (this PaneView's own root
    // Item, not any particular pane's contentArea) rather than to
    // whichever PaneLeaf ends up owning it: materialize() can be invoked
    // from more than one place for the same pane (PaneLeaf._updateContent()
    // is the one that actually reparents/anchors/shows it, but
    // PaneHeader.qml's _effectiveMenus binding also calls this, eagerly,
    // to read a freshly active tab's paneHeaderMenus -- see its comment).
    // Whichever call happens first does the actual creation; if that
    // happens to be PaneHeader's, the raw Item would otherwise sit
    // visible at (0, 0) under root's full window-filling bounds -- the
    // window's top-left corner -- until PaneLeaf's own _updateContent()
    // gets around to reparenting it. Starting hidden means there's no
    // such window in which a not-yet-placed pane can render anywhere;
    // _updateContent() is what flips visible back to true, always after
    // the reparent/anchor.
    function materialize(pane) {
        var cached = root._itemCache[pane.id];
        if (cached) {
            pane.item = cached;
            return cached;
        }
        if (pane.component) {
            pane.item = pane.component.createObject(root);
            if (pane.item) {
                root._itemCache[pane.id] = pane.item;
                pane.item.visible = false;
            }
            if (pane.item && pane.props && pane.item.paneRestore)
                pane.item.paneRestore(pane.props);
            pane.props = null;
        }
        return pane.item;
    }

    // Resolves a leaf id (see activeLeafId below) down to the concrete
    // pane node currently shown in it, plus its materialized Item --
    // backs PaneContext's "a context property reachable from anywhere"
    // for the active pane (see PaneContext.qml / Properties.qml).
    // Defaults to this controller's own activeLeafId. Reuses the same
    // tabs-drill-down logic PaneHeader.qml's own _activeTab already
    // implements (a "tabs" leaf shows its currentIndex child, a
    // standalone "pane" leaf shows itself), and calls materialize() the
    // same way PaneHeader.qml does, to guarantee the returned item
    // actually exists rather than reading a not-yet-materialized
    // pane.item that fires no change notification (see materialize()'s
    // and PaneHeader.qml's own comments on why). Returns null if the
    // leaf can't be resolved to a pane (no tree yet, unknown leafId, or
    // an empty "tabs" node).
    function resolveActivePane(leafId) {
        if (leafId === undefined)
            leafId = root.activeLeafId;
        if (!root.tree || leafId < 0)
            return null;
        var area = root._findArea(root.tree, leafId);
        if (!area)
            return null;
        var pane = null;
        if (area.type === "pane" || area.type === "toolbar")
            pane = area;
        else if (area.type === "tabs")
            pane = (area.currentIndex < area.children.length) ? area.children[area.currentIndex].node : null;
        if (!pane)
            return null;
        return {
            node: pane,
            item: root.materialize(pane)
        };
    }

    // Builds a tree from `saved` (a plain tree previously written by
    // serializeTree()). A pane whose viewType isn't in componentRegistry
    // is dropped (unknown view kind); a "split" left empty as a result
    // returns null so the caller prunes it, same as everywhere else a
    // split of fewer than two children is disallowed. A "tabs"/"drawer"
    // group is restored as-is regardless of how many children survive
    // filtering, including zero -- see _isGroupType()'s comment for why
    // groups (unlike split) are never pruned/collapsed just for being
    // small.
    function _restoreNode(saved) {
        if (!saved)
            return null;
        if (saved.type === "pane" || saved.type === "toolbar") {
            var component = root.componentRegistry[saved.viewType];
            if (!component)
                return null;
            return {
                type: saved.type,
                id: root._genId(),
                title: saved.title,
                component: component,
                viewType: saved.viewType,
                item: null,
                props: saved.props || {},
                // Restore layout attribute from top-level field (see
                // _serializeNode's comment). Falls back to 0 (absent)
                // so PaneToolbar uses its StyleKit default.
                fixedSize: saved.fixedSize || 0
            };
        }
        if (saved.type === "tabs") {
            var groupChildren = (saved.children || []).map(function (c) {
                return root._restoreNode(c.node);
            }).filter(function (c) {
                return c !== null;
            });
            var groupCurrentIndex = saved.currentIndex || 0;
            if (groupCurrentIndex >= groupChildren.length)
                groupCurrentIndex = Math.max(0, groupChildren.length - 1);
            return {
                type: "tabs",
                id: root._genId(),
                currentIndex: groupCurrentIndex,
                children: groupChildren.map(function (c) {
                    return {
                        node: c
                    };
                })
            };
        }
        if (saved.type === "drawer") {
            var drawerChildren = (saved.children || []).map(function (c) {
                return root._restoreNode(c.node);
            }).filter(function (c) {
                return c !== null;
            });
            var drawerCurrentIndex = saved.currentIndex || 0;
            if (drawerCurrentIndex >= drawerChildren.length)
                drawerCurrentIndex = Math.max(0, drawerChildren.length - 1);
            return {
                type: "drawer",
                id: root._genId(),
                expanded: saved.expanded !== false,
                orientation: saved.orientation === "horizontal" ? "horizontal" : "vertical",
                overlayWidth: saved.overlayWidth,
                overlayHeight: saved.overlayHeight,
                currentIndex: drawerCurrentIndex,
                children: drawerChildren.map(function (c) {
                    return {
                        node: c
                    };
                })
            };
        }
        if (saved.type === "split") {
            var children = (saved.children || []).map(function (c) {
                var node = root._restoreNode(c.node);
                return node ? {
                    size: c.size,
                    node: node
                } : null;
            }).filter(function (c) {
                return c !== null;
            });
            // One-time cleanup of same-orientation nesting (e.g. a
            // horizontal split directly containing another horizontal
            // split) in whatever was saved -- runs once here at startup,
            // covering layouts saved before requestDrop()/insertTab()
            // started avoiding that shape on write. Safe to do
            // unconditionally: children were just restored bottom-up
            // above, so any restored "split" child is already flattened
            // at its own level, and this only ever merges one level with
            // its immediate parent. Sizes are redistributed proportionally
            // so the flattened layout renders identically to the nested
            // one.
            var flatChildren = [];
            children.forEach(function (c) {
                if (c.node.type === "split" && c.node.orientation === saved.orientation) {
                    c.node.children.forEach(function (inner) {
                        flatChildren.push({
                            size: c.size * inner.size,
                            node: inner.node
                        });
                    });
                } else {
                    flatChildren.push(c);
                }
            });
            children = flatChildren;
            if (children.length === 0)
                return null;
            if (children.length === 1)
                return children[0].node;
            return {
                type: "split",
                id: root._genId(),
                orientation: saved.orientation,
                children: children
            };
        }
        return null;
    }

    // Writes out the current tree as a JSON-able plain object.
    // component/item are live objects and aren't included; only the
    // viewType string and (once materialized) paneSerialize()'s return
    // value are written.
    function serializeTree() {
        return root._serializeNode(root.tree);
    }

    function _serializeNode(node) {
        if (!node)
            return null;
        if (node.type === "toolbar") {
            // Look the materialized Item up by id via _itemCache rather
            // than trusting node.item: any pane nested under a "split"
            // arrives here as a QVariantMap-converted copy of the real
            // root.tree node (same Repeater-model conversion _find()'s
            // comment on setCurrentTab() describes), so materialize()'s
            // `pane.item = ...` write lands on that copy, never on the
            // canonical node this function is walking. _itemCache is keyed
            // by id precisely so lookups don't depend on object identity.
            var materializedToolbar = root._itemCache[node.id];
            var result = {
                type: node.type,
                viewType: node.viewType,
                title: node.title,
                props: (materializedToolbar && materializedToolbar.paneSerialize) ? materializedToolbar.paneSerialize() : {}
            };
            // Layout attribute -- saved at the top level of the node
            // (not inside props, which is view UI state) so it survives
            // round-trips through serializeTree/restoreTree regardless of
            // whether the view implements paneSerialize. Omitted when
            // 0/absent to keep the YAML tidy.
            if (node.fixedSize > 0)
                result.fixedSize = node.fixedSize;
            return result;
        }
        if (node.type === "pane") {
            var materializedItem = root._itemCache[node.id];
            return {
                type: node.type,
                viewType: node.viewType,
                title: node.title,
                props: (materializedItem && materializedItem.paneSerialize) ? materializedItem.paneSerialize() : {}
            };
        }
        if (node.type === "tabs") {
            return {
                type: "tabs",
                currentIndex: node.currentIndex,
                children: node.children.map(function (c) {
                    return {
                        node: root._serializeNode(c.node)
                    };
                })
            };
        }
        if (node.type === "drawer") {
            return {
                type: "drawer",
                expanded: node.expanded,
                orientation: node.orientation,
                overlayWidth: node.overlayWidth,
                overlayHeight: node.overlayHeight,
                currentIndex: node.currentIndex,
                children: node.children.map(function (c) {
                    return {
                        node: root._serializeNode(c.node)
                    };
                })
            };
        }
        return {
            type: "split",
            orientation: node.orientation,
            children: node.children.map(function (c) {
                return {
                    size: c.size,
                    node: root._serializeNode(c.node)
                };
            })
        };
    }

    PaneTreeOps {
        id: treeOps
    }

    function _cloneNode(node) {
        return treeOps.cloneNode(node);
    }

    function _find(node, targetId, parentChildren, indexInParent, parentNode) {
        return treeOps.findNode(node, targetId, parentChildren, indexInParent, parentNode);
    }

    function _findArea(node, areaId) {
        return treeOps.findArea(node, areaId);
    }

    function _findPane(node, paneId) {
        return treeOps.findPane(node, paneId);
    }

    // Switches the pane identified by paneId to a different view type in
    // place (same slot in the tree, same tab position) -- the dropdown in
    // PaneHeader.qml's top-left icon calls this, mirroring Blender's
    // editor-type switcher. The pane's previously materialized item
    // belongs to the *old* view type's component and can't be reused, so
    // it's torn down here; PaneLeaf._updateContent() then materializes a
    // fresh item from the new component once the tree change propagates.
    //
    // Clones+reassigns root.tree (rather than mutating in place, the way
    // setCurrentTab()/setSplitSizes() do) because, same as
    // requestDrop()/extractTab()/insertTab(), the pane being switched may
    // be reached through a Repeater-copied node several levels down --
    // only a full clone+reassign is guaranteed to reach every such copy.
    function changePaneType(paneId, newViewType, newTitle) {
        if (!root.tree)
            return;
        var component = root.componentRegistry[newViewType];
        if (!component)
            return;

        var newTree = root._cloneNode(root.tree);
        var pane = root._findPane(newTree, paneId);
        if (!pane)
            return;

        var oldItem = root._itemCache[pane.id];
        if (oldItem) {
            delete root._itemCache[pane.id];
            oldItem.destroy();
        }

        pane.component = component;
        pane.viewType = newViewType;
        pane.title = newTitle;
        pane.item = null;
        pane.props = null;

        root.tree = null;
        root.tree = newTree;
    }

    // Adds a brand-new pane of `viewType` as the last tab in the "tabs"
    // group identified by areaId -- backs PaneTabBar.qml's own "+"
    // button. areaId must already resolve to an actual "tabs" node (that
    // button only ever renders inside one -- see PaneTabs.qml's own
    // `visible: node.type === "tabs"` guard); no-ops otherwise, same
    // defensive style as every other mutator here. Reuses _tabsChild/
    // _paneNode the same way requestDrop()'s own "center" zone does when
    // dropping a pane onto an existing tabs group, just without a source
    // pane to remove first.
    function addPaneToTabs(areaId, viewType, title) {
        if (!root.tree)
            return;
        var component = root.componentRegistry[viewType];
        if (!component)
            return;

        var newTree = root._cloneNode(root.tree);
        var area = root._findArea(newTree, areaId);
        if (!area || area.type !== "tabs")
            return;

        var pane = {
            id: root._genId(),
            title: title,
            component: component,
            viewType: viewType,
            item: null,
            props: null
        };
        area.children.push(root._tabsChild(pane));
        area.currentIndex = area.children.length - 1;

        root.tree = null;
        root.tree = newTree;
    }

    // Whether `type` is a "group" node kind (a tab strip of some sort --
    // "tabs" or "drawer") that should never be auto-collapsed away just
    // because its children count drops to 1 or 0: unlike "split" (a
    // purely structural divider that genuinely can't mean anything with
    // only one child), the user may deliberately want an emptied-out or
    // single-tab group to stick around as a place to drop more panes
    // into later, rather than silently reverting to a bare pane (or
    // vanishing outright at zero) the moment they close down to it.
    // PaneLeaf.qml/PaneTabBar.qml (for "tabs") and PaneDrawer.qml (for
    // "drawer") both render an explicit empty-state message for the
    // zero-children case instead of just going blank.
    function _isGroupType(type) {
        return type === "tabs" || type === "drawer";
    }

    // Copies `remaining`'s own fields onto `container` in place, keeping
    // container's original id. Used when a "split" drops to one child
    // (collapses into whatever that child is) -- never for "tabs"/
    // "drawer" any more, see _isGroupType()'s comment above. Mutating in
    // place means any other reference already pointing at `container`
    // sees the collapse too, without needing to also patch container's
    // own parent.
    function _collapseInto(container, remaining) {
        for (var key in container) {
            if (key !== "id")
                delete container[key];
        }
        for (var key in remaining) {
            if (key !== "id")
                container[key] = remaining[key];
        }
    }

    // Removes the pane identified by (areaId, paneId) from `newTree` and
    // returns its own data (id/title/component/viewType/item/props).
    //
    // If areaId is a "tabs"/"drawer" node, the matching child is spliced
    // out of its children right away -- the group itself is kept as-is
    // regardless of how many children that leaves it with, including
    // zero (see _isGroupType()'s comment).
    //
    // If areaId is a standalone pane, its removal is NOT performed here
    // -- the pane node is left in the tree untouched, and the caller must
    // call _removeStandalonePane() once it's done using the *target* side
    // of the move. That mirrors how the original tab-based version always
    // spliced a tab out of its array immediately but deferred the
    // resulting empty-leaf's removal from its parent split: removing a
    // standalone pane touches a split's children by index, and doing that
    // before the target lookup could invalidate the very node/position
    // that lookup is about to use.
    function _removePane(newTree, areaId, paneId) {
        var area = root._findArea(newTree, areaId);
        if (!area)
            return null;

        if (area.type === "pane" || area.type === "toolbar") {
            if (area.id !== paneId)
                return null;
            return {
                type: area.type,
                id: area.id,
                title: area.title,
                component: area.component,
                viewType: area.viewType,
                item: area.item,
                props: area.props,
                fixedSize: area.fixedSize || 0
            };
        }
        if ((area.type === "drawer" || area.type === "tabs") && area.id === paneId) {
            return root._cloneNode(area);
        }

        var idx = -1;
        for (var i = 0; i < area.children.length; i++) {
            if (area.children[i].node.id === paneId) {
                idx = i;
                break;
            }
        }
        if (idx === -1)
            return null;
        var removedNode = area.children.splice(idx, 1)[0].node;
        if (area.currentIndex >= area.children.length)
            area.currentIndex = Math.max(0, area.children.length - 1);
        return root._cloneNode(removedNode);
    }

    // Removes a standalone pane (areaId) entirely from whichever split
    // or drawer holds it as a direct child. A "split" collapses in place
    // (see _collapseInto) if it drops to a single remaining child and
    // renormalizes its size fractions otherwise; a "drawer" never
    // collapses (see _isGroupType()'s comment) and has no size fractions
    // of its own to renormalize (its children are {node} entries, same
    // shape as "tabs" -- only "split" children carry a `size`), just a
    // currentIndex to keep in range. See _removePane's comment for why
    // this has to be called after the target side of a move has already
    // been resolved.
    function _removeStandalonePane(node, areaId) {
        if (node.type !== "split" && node.type !== "drawer")
            return false;
        for (var i = 0; i < node.children.length; i++) {
            var child = node.children[i].node;
            if (child.id === areaId) {
                node.children.splice(i, 1);
                if (root._isGroupType(node.type)) {
                    if (node.currentIndex >= node.children.length)
                        node.currentIndex = Math.max(0, node.children.length - 1);
                } else if (node.children.length === 1) {
                    root._collapseInto(node, node.children[0].node);
                } else {
                    root._renormalizeSizes(node);
                }
                return true;
            }
            if (root._removeStandalonePane(child, areaId))
                return true;
        }
        return false;
    }

    // Rescales a split's remaining children's size fractions back up to
    // sum to 1. Needed after splicing a child out of `node.children`
    // (above): PaneSplit.qml's _size()/_offset() read each child's `size`
    // fraction verbatim with no normalization of their own, so leaving
    // the survivors' fractions summing to less than 1 (their original
    // shares, minus whatever the removed child held) would leave a blank,
    // unfilled gap the width of the removed child's old share.
    function _renormalizeSizes(node) {
        var sum = 0;
        for (var i = 0; i < node.children.length; i++)
            sum += node.children[i].size;
        if (sum <= 0)
            return;
        for (var i = 0; i < node.children.length; i++)
            node.children[i].size /= sum;
    }

    // Builds a fresh pane node from pane data (id/title/component/
    // viewType/item/props), and the {node: ...} wrapper "tabs" children
    // use around one.
    function _paneNode(pane) {
        if (pane.type === "drawer" || pane.type === "tabs" || pane.type === "split") {
            return root._cloneNode(pane);
        }
        var node = {
            type: pane.type || "pane",
            id: pane.id,
            title: pane.title,
            component: pane.component,
            viewType: pane.viewType,
            item: pane.item,
            props: pane.props
        };
        if (pane.fixedSize > 0)
            node.fixedSize = pane.fixedSize;
        return node;
    }
    function _tabsChild(pane) {
        return {
            node: root._paneNode(pane)
        };
    }

    // Whether areaId is a standalone "pane" area (as opposed to a "tabs"
    // group). Used by PaneDropOverlay.qml to suppress its edge-zone drop
    // highlight for a self-drop onto a standalone pane's own area, since
    // requestDrop() silently no-ops that case for every zone (there is no
    // "other side" for a lone pane to split against, unlike popping one
    // tab out of a group alongside its siblings).
    function isStandalonePane(areaId) {
        var area = root._findArea(root.tree, areaId);
        return !!area && (area.type === "pane" || area.type === "toolbar");
    }

    // Whether areaId is a standalone "toolbar" area. Used by
    // PaneDropOverlay.qml to suppress its center-zone drop highlight
    // while dragging a toolbar -- a toolbar leaf can never join/create a
    // "tabs" group (see requestDrop()'s own center-zone guard), so
    // showing that highlight would promise a drop that then silently
    // no-ops.
    function isToolbarPane(areaId) {
        var area = root._findArea(root.tree, areaId);
        return !!area && area.type === "toolbar";
    }

    // Moves paneId (currently in area sourceAreaId) to sit relative to
    // targetAreaId, per zone ("center"|"top"|"bottom"|"left"|"right"|
    // "drawer-top"|"drawer-bottom"). The "drawer-*" zones are a thin
    // sub-band right at the very top/bottom edge (see
    // PaneDropOverlay.qml's _rawZoneFor) that produces a "drawer" node
    // instead of a plain vertical "split" -- see PaneView.qml's class
    // comment for what distinguishes the two.
    function requestDrop(sourceAreaId, paneId, targetAreaId, zone) {
        if (!root.tree || sourceAreaId < 0 || targetAreaId < 0)
            return;
        // A standalone pane dropped onto its own (only) area can never
        // produce a meaningful split -- there is nothing else there to
        // remain behind, unlike a group's child being popped out from
        // alongside its siblings. Dropping one of a group's own panes
        // back onto the group's own tab strip (zone "center") is likewise
        // just a no-op return-to-sender. Non-center self-drop onto a
        // "tabs" node is fine and handled normally below: it pops one
        // pane out of the group into its own new sibling area.
        if (sourceAreaId === targetAreaId) {
            if (zone === "center")
                return;
            var selfArea = root._findArea(root.tree, sourceAreaId);
            if (selfArea && (selfArea.type === "pane" || selfArea.type === "toolbar" || selfArea.type === "drawer" || selfArea.type === "tabs"))
                return;
        }

        var newTree = root._cloneNode(root.tree);

        var sourceArea = root._findArea(newTree, sourceAreaId);
        if (!sourceArea)
            return;
        var wasStandalone = sourceArea.type === "pane" || sourceArea.type === "toolbar" || ((sourceArea.type === "drawer" || sourceArea.type === "tabs") && sourceAreaId === paneId);

        // Captured now, before newTree is touched any further, so it still
        // points at the source's *original* slot even after the dropped
        // pane (same id, see _paneNode()) gets planted somewhere else in
        // the tree below. Removing it by a fresh by-id search afterwards
        // (the old approach) was ambiguous whenever that new slot happened
        // to be visited first by such a search: it would splice out the
        // just-planted pane instead of the stale original, silently
        // reverting the drop (e.g. dropping onto a "tabs" group's edge,
        // where the new split lands earlier in traversal order than the
        // source's old split slot).
        var sourceSlot = wasStandalone ? root._find(newTree, sourceAreaId, null, -1) : null;

        var pane = root._removePane(newTree, sourceAreaId, paneId);
        if (!pane)
            return;

        if (zone === "center") {
            var targetArea = root._findArea(newTree, targetAreaId);
            if (!targetArea)
                return;
            // A "tabs" group's children are always bare panes -- a
            // toolbar leaf must never become one, in either direction
            // (dragged onto a tabs strip, or dragged onto/receiving a
            // plain pane that would otherwise get wrapped into a brand
            // new "tabs" group alongside it). `pane` was already spliced
            // out of newTree by _removePane() above, but newTree is only
            // ever committed to root.tree at this function's very end
            // (see its class comment on clone+reassign), so returning
            // here leaves the real tree untouched -- same no-op shape as
            // every other early return in this function.
            if (targetArea.type === "tabs") {
                if (pane.type === "toolbar")
                    return;
                targetArea.children.push(root._tabsChild(pane));
                targetArea.currentIndex = targetArea.children.length - 1;
            } else {
                var foundPane = root._find(newTree, targetAreaId, null, -1);
                if (!foundPane)
                    return;
                if (pane.type === "toolbar" || foundPane.node.type === "toolbar")
                    return;
                var newGroup = {
                    type: "tabs",
                    id: root._genId(),
                    currentIndex: 1,
                    children: [root._tabsChild(foundPane.node), root._tabsChild(pane)]
                };
                if (foundPane.parentChildren === null) {
                    newTree = newGroup;
                } else {
                    foundPane.parentChildren[foundPane.index] = {
                        size: foundPane.parentChildren[foundPane.index].size,
                        node: newGroup
                    };
                }
            }
        } else if (zone === "drawer-top" || zone === "drawer-bottom") {
            var drawerFound = root._find(newTree, targetAreaId, null, -1);
            if (!drawerFound)
                return;

            var drawerNewFirst = (zone === "drawer-top");
            var drawerNode = {
                type: "drawer",
                id: root._genId(),
                expanded: true,
                orientation: "vertical",
                currentIndex: drawerNewFirst ? 0 : 1,
                children: drawerNewFirst ? [root._tabsChild(pane),
                    {
                        node: drawerFound.node
                    }
                ] : [
                    {
                        node: drawerFound.node
                    },
                    root._tabsChild(pane)]
            };

            if (drawerFound.parentChildren === null) {
                newTree = drawerNode;
            } else {
                drawerFound.parentChildren[drawerFound.index] = {
                    size: drawerFound.parentChildren[drawerFound.index].size,
                    node: drawerNode
                };
            }
        } else {
            var found = root._find(newTree, targetAreaId, null, -1);
            if (!found)
                return;

            var newPaneNode = root._paneNode(pane);
            var orientation = (zone === "left" || zone === "right") ? "horizontal" : "vertical";
            var newFirst = (zone === "left" || zone === "top");

            // If the target's own parent is already a split with the same
            // orientation, insert as a direct sibling there instead of
            // nesting a redundant same-orientation split one level deeper
            // (e.g. a horizontal split directly containing another
            // horizontal split) -- mirrors PaneTree::split_pane's
            // same-orientation merge on the Rust side.
            if (found.parentNode && found.parentNode.type === "split" && found.parentNode.orientation === orientation) {
                var insertIdx = newFirst ? found.index : found.index + 1;
                var half = found.parentChildren[found.index].size / 2;
                found.parentChildren[found.index].size = half;
                found.parentChildren.splice(insertIdx, 0, {
                    size: half,
                    node: newPaneNode
                });
                // Inserting shifts every sibling at/after insertIdx one
                // slot right. If the not-yet-removed standalone source
                // pane (see sourceSlot above) sits later in this very
                // array, its captured index must shift too, or the
                // deferred removal below would splice out the wrong
                // element.
                if (sourceSlot && sourceSlot.parentChildren === found.parentChildren && sourceSlot.index >= insertIdx) {
                    sourceSlot.index += 1;
                }
            } else {
                var children = newFirst ? [
                    {
                        size: 0.5,
                        node: newPaneNode
                    },
                    {
                        size: 0.5,
                        node: found.node
                    }
                ] : [
                    {
                        size: 0.5,
                        node: found.node
                    },
                    {
                        size: 0.5,
                        node: newPaneNode
                    }
                ];
                var splitNode = {
                    type: "split",
                    id: root._genId(),
                    orientation: orientation,
                    children: children
                };

                if (found.parentChildren === null) {
                    newTree = splitNode;
                } else {
                    found.parentChildren[found.index] = {
                        size: found.parentChildren[found.index].size,
                        node: splitNode
                    };
                }
            }
        }

        // Same splice/collapse/renormalize behavior as
        // _removeStandalonePane(), but by the position captured in
        // sourceSlot above rather than a fresh by-id search (see its
        // comment for why that's now unsafe: the target side may already
        // have planted a node reusing the same id elsewhere in newTree).
        if (wasStandalone && sourceSlot && sourceSlot.parentNode) {
            sourceSlot.parentChildren.splice(sourceSlot.index, 1);
            if (root._isGroupType(sourceSlot.parentNode.type)) {
                if (sourceSlot.parentNode.currentIndex >= sourceSlot.parentChildren.length)
                    sourceSlot.parentNode.currentIndex = Math.max(0, sourceSlot.parentChildren.length - 1);
            } else if (sourceSlot.parentChildren.length === 1) {
                root._collapseInto(sourceSlot.parentNode, sourceSlot.parentChildren[0].node);
            } else if (sourceSlot.parentChildren.length > 1) {
                root._renormalizeSizes(sourceSlot.parentNode);
            }
        }

        root.tree = null;
        root.tree = newTree;
    }

    // Removes paneId (in area areaId) from this controller's tree and
    // returns its data (without id -- id belongs to the controller's own
    // id space and isn't carried over). Paired with another PaneView's
    // (another controller's) insertTab() to move a pane across
    // controllers (e.g. sidebar <-> main area).
    function extractTab(areaId, paneId) {
        if (!root.tree)
            return null;
        var newTree = root._cloneNode(root.tree);
        var area = root._findArea(newTree, areaId);
        if (!area)
            return null;
        var wasStandalone = area.type === "pane" || area.type === "toolbar";

        var pane = root._removePane(newTree, areaId, paneId);
        if (!pane)
            return null;

        if (wasStandalone) {
            if (newTree.type === "split")
                root._removeStandalonePane(newTree, areaId);
            else
                newTree = null; // that pane was this controller's entire tree
        }

        root.tree = newTree;

        return {
            type: pane.type,
            title: pane.title,
            component: pane.component,
            viewType: pane.viewType,
            item: pane.item,
            props: pane.props
        };
    }

    // Inserts pane data (from another controller's extractTab()) as a new
    // pane, positioned relative to targetAreaId per zone
    // ("center"|"top"|"bottom"|"left"|"right"). Gets a fresh id in this
    // controller's own id space.
    function insertTab(paneData, targetAreaId, zone) {
        if (!root.tree || !paneData)
            return;
        var newTree = root._cloneNode(root.tree);
        var pane = {
            type: paneData.type || "pane",
            id: root._genId(),
            title: paneData.title,
            component: paneData.component,
            viewType: paneData.viewType,
            item: paneData.item,
            props: paneData.props
        };

        if (zone === "center") {
            var targetArea = root._findArea(newTree, targetAreaId);
            if (!targetArea)
                return;
            // Same toolbar-can-never-join/create-a-"tabs"-group guard as
            // requestDrop()'s own identical center-zone branch -- see its
            // comment.
            if (targetArea.type === "tabs") {
                if (pane.type === "toolbar")
                    return;
                targetArea.children.push(root._tabsChild(pane));
                targetArea.currentIndex = targetArea.children.length - 1;
            } else {
                var foundPane = root._find(newTree, targetAreaId, null, -1);
                if (!foundPane)
                    return;
                if (pane.type === "toolbar" || foundPane.node.type === "toolbar")
                    return;
                var newGroup = {
                    type: "tabs",
                    id: root._genId(),
                    currentIndex: 1,
                    children: [root._tabsChild(foundPane.node), root._tabsChild(pane)]
                };
                if (foundPane.parentChildren === null) {
                    newTree = newGroup;
                } else {
                    foundPane.parentChildren[foundPane.index] = {
                        size: foundPane.parentChildren[foundPane.index].size,
                        node: newGroup
                    };
                }
            }
        } else if (zone === "drawer-top" || zone === "drawer-bottom") {
            var drawerFound = root._find(newTree, targetAreaId, null, -1);
            if (!drawerFound)
                return;

            var drawerNewFirst = (zone === "drawer-top");
            var drawerNode = {
                type: "drawer",
                id: root._genId(),
                expanded: true,
                orientation: "vertical",
                currentIndex: drawerNewFirst ? 0 : 1,
                children: drawerNewFirst ? [root._tabsChild(pane),
                    {
                        node: drawerFound.node
                    }
                ] : [
                    {
                        node: drawerFound.node
                    },
                    root._tabsChild(pane)]
            };

            if (drawerFound.parentChildren === null) {
                newTree = drawerNode;
            } else {
                drawerFound.parentChildren[drawerFound.index] = {
                    size: drawerFound.parentChildren[drawerFound.index].size,
                    node: drawerNode
                };
            }
        } else {
            var found = root._find(newTree, targetAreaId, null, -1);
            if (!found)
                return;

            var newPaneNode = root._paneNode(pane);
            var orientation = (zone === "left" || zone === "right") ? "horizontal" : "vertical";
            var newFirst = (zone === "left" || zone === "top");

            // Same same-orientation merge as requestDrop()'s edge-zone
            // branch -- see its comment.
            if (found.parentNode && found.parentNode.type === "split" && found.parentNode.orientation === orientation) {
                var insertIdx = newFirst ? found.index : found.index + 1;
                var half = found.parentChildren[found.index].size / 2;
                found.parentChildren[found.index].size = half;
                found.parentChildren.splice(insertIdx, 0, {
                    size: half,
                    node: newPaneNode
                });
            } else {
                var children = newFirst ? [
                    {
                        size: 0.5,
                        node: newPaneNode
                    },
                    {
                        size: 0.5,
                        node: found.node
                    }
                ] : [
                    {
                        size: 0.5,
                        node: found.node
                    },
                    {
                        size: 0.5,
                        node: newPaneNode
                    }
                ];
                var splitNode = {
                    type: "split",
                    id: root._genId(),
                    orientation: orientation,
                    children: children
                };

                if (found.parentChildren === null) {
                    newTree = splitNode;
                } else {
                    found.parentChildren[found.index] = {
                        size: found.parentChildren[found.index].size,
                        node: splitNode
                    };
                }
            }
        }

        root.tree = newTree;
    }

    // Updates the currentIndex of the "tabs"/"drawer" node identified by
    // areaId. Called from PaneLeaf.selectTab()/PaneDrawer.qml's own tab
    // click handling. Goes through the controller (finding the real node
    // via _findArea) rather than assigning node.currentIndex directly,
    // because under a split the node a PaneLeaf/PaneDrawer instance
    // receives arrives via PaneSplit.qml's Repeater (whose model is the
    // plain JS array node.children), and its delegate gets a copy of
    // that node after a QVariantMap conversion -- assigning straight to
    // it wouldn't reach the real tree (root.tree) that gets persisted
    // (same reasoning as PaneSplit.qml's child-size write-back; see that
    // file's comment).
    function setCurrentTab(areaId, index) {
        if (!root.tree)
            return;
        var area = root._findArea(root.tree, areaId);
        if (!area || (area.type !== "tabs" && area.type !== "drawer") || index < 0 || index >= area.children.length)
            return;
        area.currentIndex = index;
    }

    // Updates a "split" node's children[].size fractions in place on the
    // live tree, identified by areaId. Same reasoning as setCurrentTab()
    // above: PaneSplit.qml's own `node` property is a QVariantMap-
    // converted Repeater-modelData copy for anything but the outermost
    // split (whose PaneNode is wired directly to root.tree, not through
    // a Repeater), so writing straight to that node's children (as that
    // file used to do) only ever reached the real, persisted tree for
    // the root split -- every resize on a nested one was silently
    // dropped from serializeTree()'s output. "drawer" never reaches
    // here: unlike the old "stack", it only ever shows one child at a
    // time (see PaneDrawer.qml), so it has no per-child size to resize.
    function setSplitSizes(areaId, sizes) {
        if (!root.tree)
            return;
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "split")
            return;
        for (var i = 0; i < sizes.length && i < found.node.children.length; i++)
            found.node.children[i].size = sizes[i];
    }

    // Updates the expanded state of the "drawer" node identified by
    // areaId. Mutates the live tree node directly rather than cloning/
    // reassigning root.tree (same reasoning as setCurrentTab() above):
    // the caller (PaneDrawer.qml) already reflects the new state
    // immediately through its own local `expanded` property, so this
    // call only needs to keep the canonical tree in sync for later
    // serialization.
    function setDrawerExpanded(areaId, expanded) {
        if (!root.tree)
            return;
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "drawer")
            return;
        found.node.expanded = expanded;
    }

    // Updates the rail orientation of the "drawer" node identified by
    // areaId -- the rail's own manual hamburger-menu toggle (see
    // PaneDrawer.qml's class comment). Mutates the live tree node
    // directly rather than cloning/reassigning root.tree, same reasoning
    // as setDrawerExpanded() above: the caller already reflects the new
    // orientation locally, this only needs to keep the persisted tree in
    // sync. A drawer that's a direct child of a "split" ignores its own
    // stored orientation at render time (forced to match the split's own
    // orientation instead -- see PaneDrawer.qml/PaneSplit.qml), so
    // calling this on such a drawer still updates the persisted field but
    // has no visible effect until it's moved out from under that split.
    function setDrawerOrientation(areaId, orientation) {
        if (!root.tree || (orientation !== "vertical" && orientation !== "horizontal"))
            return;
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "drawer")
            return;
        found.node.orientation = orientation;
    }

    // Updates the collapsed-tab overlay's resizable dimension for the
    // "drawer" node identified by areaId -- see PaneDrawer.qml's
    // overlayPopup comment. Two independent fields (rather than one
    // shared "size") because the vertical-rail overlay's free dimension
    // is width and the horizontal-rail overlay's is height, and each
    // persists independently of which orientation is currently in effect
    // -- toggling orientation back and forth doesn't lose either one's
    // remembered size. Same mutate-in-place reasoning as
    // setDrawerExpanded()/setDrawerOrientation() above (neither changes
    // node.type, so no clone is needed).
    function setDrawerOverlayWidth(areaId, width) {
        if (!root.tree)
            return;
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "drawer")
            return;
        found.node.overlayWidth = width;
    }

    function setDrawerOverlayHeight(areaId, height) {
        if (!root.tree)
            return;
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "drawer")
            return;
        found.node.overlayHeight = height;
    }

    // Converts the "tabs"/"drawer" node identified by areaId into the
    // other group type in place. Unlike the old "stack", "drawer" now
    // shares the exact same {node} child-array shape "tabs" already
    // uses (plus its own `expanded` field), so no per-child reshaping is
    // needed here -- just the `type`/`expanded` fields. Still needs the
    // clone+reassign pattern (see this file's class comment): it changes
    // node.type itself, which PaneNode.qml's Loader dispatches on, and
    // mutating a plain JS object's field in place fires no QML change
    // notification that would make the Loader re-evaluate its source.
    //
    // No-ops if areaId isn't currently a tabs/drawer node, or already is
    // newType. Converting drawer -> tabs additionally requires every
    // child to already be a standalone "pane" -- a tab strip has no way
    // to show a nested split/drawer/tabs, unlike a drawer's children
    // which can be any node type. canConvertDrawerToTabs() below lets
    // the UI gray out that option instead of offering a silent no-op.
    function setGroupType(areaId, newType) {
        if (!root.tree || (newType !== "tabs" && newType !== "drawer"))
            return;
        var newTree = root._cloneNode(root.tree);
        var found = root._find(newTree, areaId, null, -1);
        if (!found)
            return;
        var area = found.node;
        if (area.type === newType || (area.type !== "tabs" && area.type !== "drawer"))
            return;

        if (newType === "drawer") {
            area.expanded = true;
        } else {
            for (var i = 0; i < area.children.length; i++) {
                if (area.children[i].node.type !== "pane")
                    return;
            }
            delete area.expanded;
        }
        area.type = newType;

        root.tree = null;
        root.tree = newTree;
    }

    // Whether the "drawer" node identified by areaId can be converted to
    // "tabs" via setGroupType() above -- true only if every one of its
    // children is already a standalone "pane". Read-only (looks at the
    // live tree, no clone needed), so the UI can use it to gray out the
    // "convert to tabs" menu item instead of offering a silent no-op.
    function canConvertDrawerToTabs(areaId) {
        var found = root._find(root.tree, areaId, null, -1);
        if (!found || found.node.type !== "drawer")
            return false;
        for (var i = 0; i < found.node.children.length; i++) {
            if (found.node.children[i].node.type !== "pane")
                return false;
        }
        return true;
    }

    function closeTab(areaId, paneId) {
        if (!root.tree)
            return;
        var newTree = root._cloneNode(root.tree);
        var area = root._findArea(newTree, areaId);
        if (!area)
            return;

        if (area.type === "pane" || area.type === "toolbar") {
            if (area.id !== paneId)
                return;
            if (newTree.type !== "split" && newTree.type !== "drawer") {
                root.tree = null; // closing this controller's only pane
                return;
            }
            root._removeStandalonePane(newTree, areaId);
            root.tree = newTree;
            return;
        }

        var idx = -1;
        for (var i = 0; i < area.children.length; i++) {
            if (area.children[i].node.id === paneId) {
                idx = i;
                break;
            }
        }
        if (idx === -1)
            return;

        area.children.splice(idx, 1);
        if (area.currentIndex >= area.children.length)
            area.currentIndex = Math.max(0, area.children.length - 1);

        root.tree = null;
        root.tree = newTree;
    }

    // Same tree removal as closeTab(), for callers that have already taken
    // ownership of the pane's live Item elsewhere (e.g. PaneHeader.qml's
    // "別ウィンドウに移動" reparenting it into a new PaneWindow) instead of
    // letting it fall through to PaneLeaf.qml's own dragLayer-eviction
    // path. Purges the _itemCache entry too -- same reasoning
    // changePaneType() already applies (line ~561): without this, a future
    // pane that happens to reuse this id would find and incorrectly reuse
    // the stale (now window-owned) Item.
    function detachPane(areaId, paneId) {
        delete root._itemCache[paneId];
        root.closeTab(areaId, paneId);
    }

    // Closes every tab/pane in a "tabs"/"drawer" group (areaId) at once,
    // leaving the group itself in place -- empty, same as closing tabs
    // one at a time down to zero already leaves it (see _isGroupType()'s
    // own comment on why an empty group isn't auto-collapsed away). Use
    // closeGroup() below instead to remove the group node itself too.
    function closeAllTabs(areaId) {
        if (!root.tree)
            return;
        var newTree = root._cloneNode(root.tree);
        var area = root._findArea(newTree, areaId);
        if (!area || !root._isGroupType(area.type))
            return;

        area.children = [];
        area.currentIndex = 0;

        // Same null-then-reassign as closeTab()'s own splice-from-
        // group.children branch above (the structurally closest analog --
        // this also mutates a group's `children` array in place) rather
        // than this function's own earlier single-step `root.tree =
        // newTree`, which left downstream bindings into the now-emptied
        // group (e.g. PaneTabBar.qml's hamburger `menuItems`, reading
        // `root.node.children`) reading a stale/undefined `node` --
        // confirmed live by the user ("Value is undefined and could not
        // be converted to an object" at PaneTabBar.qml's menuItems).
        root.tree = null;
        root.tree = newTree;
    }

    // Closes a "tabs"/"drawer" group node (areaId) wholesale -- as
    // opposed to closeTab(), which only ever closes one member within
    // it. _removeStandalonePane() is generic over what it removes (it
    // matches by id alone, not by node type -- see its own comment), so
    // it already does the right thing here: splice this group out of
    // whichever split/drawer holds it, collapsing a "split" that drops to
    // a single remaining child same as removing a standalone pane would.
    // If this group *is* the tree's own root (not nested in any split/
    // drawer), closing it empties the whole tree, same as closeTab()'s
    // own root-pane case.
    function closeGroup(areaId) {
        if (!root.tree)
            return;
        var newTree = root._cloneNode(root.tree);
        if (newTree.id === areaId) {
            root.tree = null;
            return;
        }

        root._removeStandalonePane(newTree, areaId);
        root.tree = newTree;
    }

    // Whether a tab drag is currently in progress. The sidebar
    // (OverlayDrawer)'s interactiveResizeEnabled resize handle sits right
    // at its edge pixels, and dragging a pane from the main area onto the
    // sidebar (crossing that edge) lets the handle steal the grab, forcing
    // the pane drag to end in canceled. The caller (main.qml) watches this
    // flag to disable the sidebar's interactiveResizeEnabled only while a
    // drag is active.
    property bool dragActive: false

    // When true, disables drag-to-move (tab header/6dot grip) everywhere
    // in this controller's tree and hides the grip; tab switching
    // (PaneTabHeader's onClicked path) is deliberately left untouched.
    // Independent of resizeLocked below. Toggled from main.qml's "表示"
    // menu; PaneTabHeader.qml/PaneHeader.qml read it via their own
    // `controller` property.
    property bool layoutLocked: false

    // When true, disables split divider dragging everywhere in this
    // controller's tree. Independent of layoutLocked above. Toggled from
    // main.qml's "表示" menu; PaneSplit.qml reads it via its own
    // `controller` property.
    property bool resizeLocked: false

    // Which leaf (a standalone "pane" node, or a "tabs" node -- either
    // way, one split/drawer cell) the user last clicked into. Pure runtime
    // UI state, not persisted: -1 (no leaf id is ever <= 0, see _genId())
    // until the first click anywhere in the tree. PaneLeaf.qml reports
    // clicks via setActivePane() below; PaneHeader.qml compares its own
    // leafId against this to draw an accent line under the active pane's
    // header.
    property int activeLeafId: -1

    function setActivePane(leafId) {
        if (root.activeLeafId !== leafId)
            root.activeLeafId = leafId;
    }

    // Which leaf (if any) is currently "maximized" -- temporarily filling
    // this whole PaneView in place of the split/drawer tree it actually
    // lives in (Blender's "Toggle Maximize Area"). -1 (no leaf id is ever
    // <= 0, see _genId()) means nothing is maximized. The tree itself is
    // untouched while maximized -- only which node the root PaneNode below
    // is pointed at changes (see _displayNode) -- so restoring is just
    // resetting this back to -1. Toggled from each view's own
    // paneHeaderMenus "表示" entry (acting on activeLeafId) and from
    // PaneMaximizeBar.qml's back button.
    property int maximizedLeafId: -1

    function toggleMaximize(leafId) {
        root.maximizedLeafId = (root.maximizedLeafId === leafId) ? -1 : leafId;
    }

    // The node maximizedLeafId currently resolves to, or null if nothing's
    // maximized -- including a maximized leaf that no longer exists (its
    // pane got closed while maximized): _displayNode below falls back to
    // root.tree whenever this is null, so that disappearance silently
    // restores the full layout instead of leaving the PaneView pointed at
    // a dangling node.
    readonly property var _maximizedArea: (root.maximizedLeafId >= 0 && root.tree) ? root._findArea(root.tree, root.maximizedLeafId) : null

    // What the root PaneNode below actually renders: the maximized leaf's
    // own node in place of the whole tree, or the tree itself otherwise.
    readonly property var _displayNode: root._maximizedArea || root.tree

    onTreeChanged: {
        if (root.maximizedLeafId >= 0 && !root._maximizedArea)
            root.maximizedLeafId = -1;
    }

    // Tab header drag start/end. Positions dragProxy (the hit-testing
    // point) exactly at the pressed cursor position before showing it
    // (anchoring it to e.g. headerItem's top-left instead would leave the
    // offset from the actual press point stuck for the whole drag).
    function beginDrag(headerItem, proxyItem, localX, localY) {
        var pos = headerItem.mapToItem(root, localX, localY);
        proxyItem.x = pos.x;
        proxyItem.y = pos.y;
        proxyItem.visible = true;
        root.dragActive = true;
    }

    function endDrag(proxyItem) {
        proxyItem.visible = false;
        root.dragActive = false;
    }

    Origami.PaneNode {
        anchors.fill: parent
        node: root._displayNode
        controller: root
    }

    // Temporary home for the drag proxy and for Items evacuated from a
    // destroyed PaneLeaf. Coordinates are root-relative.
    property alias dragLayer: dragLayer
    Item {
        id: dragLayer
        anchors.fill: parent
        z: 1000
    }
}
