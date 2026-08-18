import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Renders a "toolbar" node: always a single view, never a tab strip --
// unlike PaneLeaf.qml (which this closely mirrors, trimmed down), a
// toolbar leaf's node.type is never "tabs", so there's exactly one pane
// to materialize/evacuate here, not a currentIndex-selected list of them.
// See PaneNode.qml's fixedSizePx/PaneSplit.qml for how a toolbar cell gets
// its fixed size from its parent split, and PaneView.qml's requestDrop()/
// insertTab() center-zone guards for why a toolbar can never become a
// "tabs" child.
//
// Deliberately has no Origami.PaneHeader (unlike PaneLeaf.qml's own
// grouped-header-plus-content) -- there's no drag-grip or view-type
// switcher here yet. PaneHeader's own ViewTypePickerButton drives
// changePaneType(), which PaneView.qml only resolves for a "pane" node
// (_findPane() -- see its own comment for why that's deliberately left
// toolbar-excluded), so wiring PaneHeader in as-is would add a picker
// button that silently no-ops on a toolbar leaf. Left for whenever this
// leaf's actual content is decided (see cettila's crates/views/toolbar
// README.md) rather than solved speculatively now.
Item {
    id: root
    property var node
    property var controller

    // Whether this leaf's own "group frame" (margin + border) should be
    // drawn -- always false for a toolbar (see PaneNode.qml's framed
    // binding, which excludes "toolbar" the same way it excludes "pane"),
    // kept only so the Loader in PaneNode.qml can set it unconditionally
    // the same way it does for every other loaded leaf type without
    // needing a per-type hasOwnProperty check.
    property bool framed: false

    // Fixed size of this toolbar cell along its parent split's axis, in
    // px. Read by PaneNode.qml and forwarded to PaneSplit.qml so it gives
    // this cell an exact pixel allocation rather than a proportional share.
    //
    // Prefers node.props.fixedSize when present, so workspace.yaml can
    // override the default per-toolbar:
    //   props:
    //     fixedSize: 28
    // Falls back to StyleKit.Units.toolbarSize when absent.
    readonly property real fixedSizePx: (!!root.node && !!root.node.props && root.node.props.fixedSize > 0)
        ? root.node.props.fixedSize
        : StyleKit.Units.toolbarSize

    // Whether this leaf should actually materialize/show its content --
    // same "materialize once, stay warm" idiom as PaneLeaf.qml's own
    // `active` (see its comment); always true in practice today since
    // nothing currently sets this false for a toolbar the way
    // PaneDrawer.qml's body/overlay Repeaters do for PaneLeaf, but kept
    // for parity with PaneNode.qml's Loader, which sets it unconditionally
    // on whatever gets loaded.
    property bool active: true

    onActiveChanged: {
        if (root.active)
            root._updateContent();
    }

    // Set by PaneNode.qml's passthrough (see PaneSplit.qml's Repeater
    // delegate) to the enclosing split's own orientation, or "" if this
    // toolbar isn't a direct split child -- same mechanism, same reason,
    // as PaneDrawer.qml's own identical splitOrientation property (see
    // its class comment): a toolbar's own fixed dimension must stay
    // aligned with whichever axis the enclosing split actually resizes,
    // so a horizontal split (side-by-side cells, resized along width)
    // forces a narrow/tall "vertical" toolbar, a vertical split (stacked
    // cells, resized along height) forces a short/wide "horizontal" one.
    // Unlike PaneDrawer, there's no manual override here -- no hamburger
    // menu on a toolbar leaf yet (see this file's class comment) -- so
    // this is the only input to effectiveOrientation below; not a direct
    // split child (root of the tree, or nested in a "drawer") just falls
    // back to "horizontal", the more typical toolbar-bar shape.
    property string splitOrientation: ""
    readonly property string effectiveOrientation: root.splitOrientation === "horizontal" ? "vertical" : root.splitOrientation === "vertical" ? "horizontal" : "horizontal"
    readonly property bool horizontal: root.effectiveOrientation === "horizontal"
    // Re-stamps the materialized content's own `horizontal` (see
    // _updateContent() below) whenever this toolbar gets dragged to a
    // split with the other orientation -- effectiveOrientation has real
    // QML change notification (unlike node.orientation-style plain JS
    // fields elsewhere in this file), so this fires correctly.
    onHorizontalChanged: root._updateContent()

    // Snapshotted the same way PaneLeaf.qml's own _panes is, and for the
    // same reason: node is a live binding via PaneNode.qml, and at the
    // moment a tree rebuild replaces this area with something else, node
    // can get re-evaluated before this PaneToolbar itself is destroyed --
    // Component.onDestruction below needs the pane this leaf was actually
    // showing, not whatever node points at by then.
    property var _pane: null

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    onNodeChanged: {
        root._pane = root.node;
        root._updateContent();
    }
    onControllerChanged: root._updateContent()

    function _updateContent() {
        if (!node || !controller || !root.active)
            return;
        var item = controller.materialize(node);
        if (item) {
            item.parent = contentArea;
            item.anchors.fill = contentArea;
            item.visible = true;
            // Same leafId stamping as PaneLeaf.qml's own _updateContent()
            // -- see its comment for why this is re-stamped on every call
            // rather than just once.
            if (item.leafId !== undefined)
                item.leafId = node.id;
            // Duck-typed, same idiom as leafId above -- lets a toolbar's
            // actual content (once decided, see crates/views/toolbar
            // README.md) lay itself out as a row or column to match
            // root.horizontal, without every toolbar-hosting view being
            // required to declare this property.
            if (item.horizontal !== undefined)
                item.horizontal = root.horizontal;
        }
    }

    Component.onCompleted: {
        root._pane = root.node;
        root._updateContent();
    }
    Component.onDestruction: {
        if (!controller || !root._pane)
            return;
        var it = root._pane.item;
        if (it && it.parent === contentArea) {
            it.parent = root.controller.dragLayer;
            it.visible = false;
        }
    }

    // Same passive-grab "the user just clicked into this leaf" report as
    // PaneLeaf.qml's own identical TapHandler -- see its comment.
    TapHandler {
        acceptedButtons: Qt.AllButtons
        grabPermissions: PointerHandler.ApprovesTakeOverByAnything
        onGrabChanged: (transition, point) => {
            if (transition === 1 && root.controller && root.node)
                root.controller.setActivePane(root.node.id);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Origami.PaneBackdrop.imagePath.length > 0 ? Qt.rgba(root.colors.backgroundColor.r, root.colors.backgroundColor.g, root.colors.backgroundColor.b, Origami.PaneBackdrop.paneOpacity) : root.colors.backgroundColor
    }

    Item {
        id: contentArea
        anchors.fill: parent
        // Same reasoning as PaneLeaf.qml's own contentArea: a custom
        // Vulkan-rendered view (unlikely for a toolbar, but not
        // categorically excluded) can paint past its own item bounds.
        clip: true
    }

    Origami.PaneDropOverlay {
        anchors.fill: parent
        leafId: root.node ? root.node.id : -1
        controller: root.controller
    }
}
