import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Renders an area: either a standalone "pane" node (just its own view),
// or a "tabs" node (tab strip switching between its pane children, plus
// the currently active child's view). See PaneView.qml for what
// distinguishes the two.
//
// The displayed pane's content (pane.item) is reparented under
// contentArea and reused as-is. When this PaneLeaf itself gets destroyed
// (tree rebuild), the currently shown Item is evacuated to
// controller.dragLayer first, decoupling that Item's lifetime from this
// PaneLeaf's (otherwise Explorer/GraphView etc. would get recreated every
// time the tree changes anywhere unrelated).
Item {
    id: root
    property var node
    property var controller
    property int currentIndex: (node && node.type === "tabs") ? node.currentIndex : 0

    // Whether this leaf's own "group frame" (margin + border around
    // header+content, tab strip excluded -- see below) should be drawn.
    // Set by the caller, PaneNode.qml: see its comment for why that
    // decision lives there rather than being a node.type check here.
    property bool framed: false

    // Per-corner radius for this leaf's own outer background/border,
    // all 0 (square, unchanged) by default. Set by PaneDrawer.qml (via
    // PaneNode.qml) on its own body content, so that content's own
    // corner actually matches the enclosing group frame's rounded corner
    // instead of sitting flush at the exact same point with nothing
    // rounded about it -- see PaneDrawer.qml's own comment on its
    // bodyArea for the full reasoning.
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0

    // Whether this leaf should actually materialize/show its current
    // pane's content right now. Defaults to true -- every call site
    // except PaneDrawer.qml's own body/overlay Repeaters wants its
    // content built as soon as node/controller are known (split cells,
    // top-level workspace panes, tabs content). PaneDrawer sets this
    // false for every child except the currently selected one (via
    // PaneNode.qml's own `active` passthrough -- see its comment),
    // deferring each drawer child's real construction cost until it's
    // actually switched to, instead of paying for every child up front
    // at startup. "Materialize once, stay warm": once true and
    // materialized, flipping back to false later (switching to a
    // different drawer child) does not tear anything down -- see
    // onActiveChanged below and _updateContent()'s own comment.
    property bool active: true

    onActiveChanged: {
        if (root.active)
            root._updateContent();
    }

    // node is a live binding via PaneNode.qml, and at the moment a tree
    // rebuild replaces this area with a split, node can get re-evaluated
    // to point at that split node (which has neither "pane" nor "tabs"
    // fields) before this PaneLeaf itself is destroyed. So the pane list
    // used to evacuate the currently shown Item (Component.onDestruction)
    // is snapshotted here while node still actually points at a
    // pane/tabs node.
    property var _panes: []

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // Whether this leaf is the one currently maximized (see PaneView.qml's
    // maximizedLeafId) -- filling the whole PaneView in place of the
    // split/drawer tree it actually lives in. Derived straight from
    // controller/node rather than passed down through PaneNode.qml: once
    // maximized, PaneView.qml's root PaneNode is pointed directly at this
    // leaf's own node (see _displayNode), so this is the only PaneLeaf
    // instance for which the comparison can ever be true to begin with.
    readonly property bool maximized: !!(root.controller && root.node && root.controller.maximizedLeafId === root.node.id)

    // Whether the currently shown tab's content is reporting an error (an
    // optional `hasError` property views may expose -- same duck-typed
    // idiom PaneHeader.qml already uses for paneHeaderMenus/etc., see its
    // _activeItem comment). Reused from PaneHeader below (id: paneHeader)
    // rather than resolved again here, so there's one materialize() call
    // for the active tab, not two.
    readonly property bool _hasError: !!(paneHeader._activeItem && paneHeader._activeItem.hasError)

    onNodeChanged: {
        root.currentIndex = (node && node.type === "tabs") ? node.currentIndex : 0;
        root._panes = root._panesOf(node);
        root._updateContent();
    }
    onControllerChanged: root._updateContent()

    // "tabs" children are wrapped as {node: pane} (see PaneView.qml), so
    // unwrap each one to get the actual pane objects this leaf displays.
    function _panesOf(n) {
        if (!n)
            return [];
        if (n.type === "tabs")
            return n.children.map(function (c) {
                return c.node;
            });
        if (n.type === "pane")
            return [n];
        return [];
    }

    function selectTab(index) {
        if (!node || node.type !== "tabs" || index === root.currentIndex)
            return;
        // controller.setCurrentTab() rewrites the real area on
        // root.tree's side (see PaneView.qml::setCurrentTab's comment:
        // under a split, this node property may be a copy handed down
        // through PaneSplit.qml's Repeater, so assigning to it directly
        // wouldn't reach the tree that actually gets persisted).
        if (root.controller && node.id !== undefined)
            root.controller.setCurrentTab(node.id, index);
        root.currentIndex = index;
        root._updateContent();
    }

    // node/controller are assigned in two separate steps from
    // PaneNode.qml's Loader.onLoaded, so do nothing until both are set.
    // Also do nothing if node (mid re-evaluation just before destruction)
    // no longer points at a pane/tabs node.
    function _updateContent() {
        if (!node || !controller)
            return;
        var panes = root._panesOf(node);
        for (var i = 0; i < panes.length; i++) {
            var pane = panes[i];
            if (i === root.currentIndex) {
                // While inactive, deliberately do nothing here rather
                // than materialize -- see root.active's own comment.
                // Once active flips true, onActiveChanged re-runs this
                // function and takes this branch for real.
                if (root.active) {
                    var item = controller.materialize(pane);
                    if (item) {
                        item.parent = contentArea;
                        item.anchors.fill = contentArea;
                        item.visible = true;
                        // Tells the view which leaf it's actually showing
                        // in right now -- duck-typed (same optional-
                        // interface pattern as paneHeaderMenus/paneRestore/
                        // hasError) since not every view declares this
                        // property. A view's own paneHeaderMenus "ペインを
                        // 最大化" entry needs this: without it, there's no
                        // way for that entry to know its own leaf id, so
                        // it used to fall back to the workspace-wide
                        // "currently active pane" instead -- wrong once
                        // that's a different pane than the one whose menu
                        // was actually clicked. node.id is the same value
                        // already handed to PaneHeader/PaneTabs/
                        // PaneMaximizeBar/PaneDropOverlay below as
                        // `leafId` -- re-stamped here on every
                        // _updateContent() call (not just once) since a
                        // pane's owning leaf can change later, e.g. a
                        // drag-and-drop move to a different tabs group.
                        if (item.leafId !== undefined)
                            item.leafId = node.id;
                    }
                }
            } else if (pane.item) {
                pane.item.visible = false;
            }
        }
    }

    Component.onCompleted: {
        root._panes = root._panesOf(node);
        root._updateContent();
    }
    Component.onDestruction: {
        if (!controller)
            return;
        for (var i = 0; i < root._panes.length; i++) {
            var it = root._panes[i].item;
            if (it && it.parent === contentArea) {
                it.parent = root.controller.dragLayer;
                it.visible = false;
            }
        }
    }

    // Reports "the user just clicked into this pane" to the controller,
    // for PaneHeader.qml's active-pane accent line -- a passive grab
    // (same GrabPassive idiom NodeGraphView.qml/BoardView.qml already use
    // for their own forceActiveFocus(), see ThemedMenu.qml's class
    // comment for why: `transition === 1` is QPointingDevice.GrabPassive,
    // not exposed as a named enum to QML) so this never competes with or
    // steals the press from whatever's actually under the cursor --
    // content views keep their own grab/gesture handling untouched, this
    // just additionally observes the same press.
    TapHandler {
        acceptedButtons: Qt.AllButtons
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onGrabChanged: (transition, point) => {
            if (transition === 1 && root.controller && root.node)
                root.controller.setActivePane(root.node.id);
        }
    }

    // Fully opaque (unchanged from before PaneBackdrop.qml existed) unless
    // the user has actually picked a background image -- in which case
    // this is drawn at PaneBackdrop.paneOpacity instead, letting main.qml's
    // window-filling Image show through the pane content area.
    Rectangle {
        anchors.fill: parent
        color: Origami.PaneBackdrop.imagePath.length > 0 ? Qt.rgba(root.colors.backgroundColor.r, root.colors.backgroundColor.g, root.colors.backgroundColor.b, Origami.PaneBackdrop.paneOpacity) : root.colors.backgroundColor
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Replaces PaneTabs entirely while maximized -- see this file's
        // `maximized` comment and PaneMaximizeBar.qml's own class comment
        // for why a maximized leaf shows only a back button up top rather
        // than its normal tab strip.
        // Loader-gated (active only while this leaf is actually the
        // maximized one) rather than always built + visible-toggled: at
        // most one leaf across the whole app is ever maximized at a
        // time, so every other leaf previously paid for a fully
        // materialized (if hidden) HeaderBar+IconButton tree for
        // nothing. `visible` kept alongside `active` (same condition) so
        // ColumnLayout still excludes this from layout sizing while
        // inactive, same as it did when this was a plain invisible Item
        // (Qt Quick Layouts skip invisible children entirely --
        // Layout.preferredHeight below would otherwise reserve blank
        // space here even with nothing loaded). Layout.preferredHeight
        // pinned to the same constant PaneMaximizeBar.qml itself uses,
        // rather than relying on implicitHeight propagating up through
        // the Loader while active (both amount to the same number, but
        // this doesn't depend on Loader's item-not-yet-loaded timing).
        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleKit.Units.gridUnit * 1.6
            active: root.maximized
            visible: root.maximized
            sourceComponent: Origami.PaneMaximizeBar {
                controller: root.controller
                leafId: root.node ? root.node.id : -1
            }
        }

        // Loader-gated the same way and for the same reason as the
        // maximize-bar Loader above: a standalone "pane" leaf (the
        // tree's default shape, see PaneView.qml's class comment) never
        // shows a tab strip at all, so building PaneTabs' full
        // PaneTabBar (HeaderBar + search field + view-type picker +
        // hamburger + Repeater) for every such leaf just to hide it was
        // pure waste -- most leaves in an ordinary workspace are exactly
        // this case.
        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleKit.Units.gridUnit * 1.6
            active: !root.maximized && !!(root.node && root.node.type === "tabs")
            visible: active
            sourceComponent: Origami.PaneTabs {
                node: root.node
                leafId: root.node ? root.node.id : -1
                currentIndex: root.currentIndex
                controller: root.controller
                onTabClicked: index => root.selectTab(index)
                onTabCloseRequested: tabId => root.controller.closeTab(root.node.id, tabId)
            }
        }

        // Wraps PaneHeader + contentArea together so the "grouped content"
        // frame below encloses the header too, instead of just the
        // content -- but not the tab strip above, which stays outside the
        // frame as the interactive element you use to switch between the
        // group's members.
        Item {
            id: groupArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: (root.framed || root.maximized) ? StyleKit.Units.groupContentMargin : 0
            // No top margin: the tab strip above already provides the
            // visual gap, so adding one here would double it up.
            Layout.topMargin: 0

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Origami.PaneHeader {
                    id: paneHeader
                    Layout.fillWidth: true
                    node: root.node
                    leafId: root.node ? root.node.id : -1
                    currentIndex: root.currentIndex
                    controller: root.controller
                }

                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // GraphView etc. draw through a custom Vulkan render
                    // node and can paint past their own item bounds, so
                    // clip explicitly to avoid spilling over PaneHeader
                    // above.
                    clip: true
                    // NOTE: when this pane is the body content of a
                    // framed PaneDrawer.qml drawer (root.bottomLeftRadius/
                    // bottomRightRadius > 0), this clip is only
                    // rectangular, so a custom Vulkan-rendered view here
                    // (GraphView/NodeGraphView/BoardView/GraphMapView/
                    // GraphView3D) still shows a square corner instead of
                    // matching the group frame's rounded one -- a
                    // `MultiEffect`(`layer.effect`)-based mask was tried
                    // and abandoned (acceptable for plain/non-GPU
                    // content, but jagged/mildly unstable specifically
                    // for continuously-repainting Vulkan content); avoid
                    // reattempting this the same way.

                    // A "tabs" group is never auto-collapsed away just
                    // for running out of tabs (see PaneView.qml's
                    // _isGroupType() comment) -- closing its last tab
                    // leaves it sitting empty instead, so this says so
                    // rather than just showing blank space.
                    Origami.Label {
                        anchors.centerIn: parent
                        visible: root.node && root.node.type === "tabs" && root.node.children.length === 0
                        type: "secondary"
                        text: "タブがありません"
                    }
                }
            }

            // Frames the grouped header + content just inside the margin
            // above. z above the reparented view (which defaults to z: 0)
            // so the border doesn't end up painted over by the view's own
            // background.
            Rectangle {
                anchors.fill: parent
                z: 1
                visible: root.framed || root.maximized
                radius: StyleKit.Units.cornerRadius
                color: "transparent"
                border.width: StyleKit.Units.borderWidth
                border.color: root.colors.borderColor
            }

            // Error border: independent of root.framed (shows even on an
            // otherwise-borderless standalone pane), and above it (z: 2)
            // so it wins visually when both would apply. Only reflects the
            // currently shown tab -- see root._hasError's comment.
            Rectangle {
                anchors.fill: parent
                z: 2
                visible: root._hasError
                radius: StyleKit.Units.cornerRadius
                color: "transparent"
                border.width: StyleKit.Units.borderWidth * 2
                border.color: StyleKit.Theme.negativeTextColor
            }
        }
    }

    Origami.PaneDropOverlay {
        anchors.fill: parent
        leafId: root.node ? root.node.id : -1
        controller: root.controller
    }
}
