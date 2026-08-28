import QtQuick
import StyleKit 1.0 as StyleKit

// leaf全面を覆う透明なドロップ領域。ドラッグ中のポインタ位置に応じて
// 上下左右の縁(分割)か中央(タブとして統合)かを判定し、対応する
// ハイライトを表示する。
DropArea {
    id: root
    property int leafId: -1
    property var controller
    keys: ["pane-tab"]

    property var _dragSource: null

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // hoverZoneは自前で保持せず、常に_dragSource(dragProxy)側の状態から導出
    readonly property string hoverZone: (root._dragSource && root._dragSource.hoverController === root.controller && root._dragSource.hoverLeafId === root.leafId) ? root._dragSource.hoverZone : ""

    function _updateHoverTarget(drag, zone) {
        root._dragSource = drag.source;
        if (drag.source) {
            drag.source.hoverController = root.controller;
            drag.source.hoverLeafId = root.leafId;
            drag.source.hoverZone = zone;
            drag.source.hoverTargetIndex = -1;
        }
    }

    readonly property bool isDraggingToolbarOrDrawer: {
        if (!root._dragSource || !root.controller)
            return false;
        var lid = root._dragSource.leafId;
        if (root.controller.isToolbarPane(lid))
            return true;
        var area = root.controller._findArea(root.controller.tree, lid);
        return !!area && (area.type === "toolbar" || area.type === "drawer");
    }

    function _zoneFor(x, y, drag) {
        if (drag.source && drag.source.leafId === root.leafId && root.controller && root.controller.isStandalonePane(root.leafId)) {
            var rawZone = root._rawZoneFor(x, y);
            if (rawZone.indexOf("root-") !== 0)
                return "";
            if (root.controller.tree && (root.controller.tree.type === "pane" || root.controller.tree.type === "toolbar"))
                return "";
        }
        var raw = root._rawZoneFor(x, y);
        if (raw === "center" && root.controller && ((drag.source && root.controller.isToolbarPane(drag.source.leafId)) || root.controller.isToolbarPane(root.leafId)))
            return "";
        return raw;
    }

    readonly property real drawerEdge: 16
    readonly property real rootEdge: 24

    function _rawZoneFor(x, y) {
        if (root.controller) {
            var posInRoot = root.mapToItem(root.controller, x, y);
            var rootW = root.controller.width;
            var rootH = root.controller.height;

            if (posInRoot.x >= 0 && posInRoot.x < root.rootEdge)
                return root.isDraggingToolbarOrDrawer ? "root-drawer-left" : "root-left";
            if (posInRoot.x <= rootW && posInRoot.x > rootW - root.rootEdge)
                return root.isDraggingToolbarOrDrawer ? "root-drawer-right" : "root-right";
            if (posInRoot.y >= 0 && posInRoot.y < root.rootEdge)
                return root.isDraggingToolbarOrDrawer ? "root-drawer-top" : "root-top";
            if (posInRoot.y <= rootH && posInRoot.y > rootH - root.rootEdge)
                return root.isDraggingToolbarOrDrawer ? "root-drawer-bottom" : "root-bottom";
        }

        if (root.isDraggingToolbarOrDrawer) {
            if (y < root.drawerEdge)
                return "drawer-top";
            if (y > height - root.drawerEdge)
                return "drawer-bottom";
            if (x < root.drawerEdge)
                return "drawer-left";
            if (x > width - root.drawerEdge)
                return "drawer-right";
        }
        var edge = Math.min(width, height) * 0.28;
        edge = Math.min(edge, 90);
        if (x < edge)
            return "left";
        if (x > width - edge)
            return "right";
        if (y < root.drawerEdge)
            return "drawer-top";
        if (y < edge)
            return "top";
        if (y > height - root.drawerEdge)
            return "drawer-bottom";
        if (y > height - edge)
            return "bottom";
        return "center";
    }

    onPositionChanged: drag => {
        drag.accept();
        root._updateHoverTarget(drag, root._zoneFor(drag.x, drag.y, drag));
    }
    onEntered: drag => {
        drag.accept();
        root._updateHoverTarget(drag, root._zoneFor(drag.x, drag.y, drag));
    }
    onExited: {
        if (root._dragSource && root._dragSource.hoverController === root.controller && root._dragSource.hoverLeafId === root.leafId) {
            root._dragSource.hoverController = null;
            root._dragSource.hoverLeafId = -1;
            root._dragSource.hoverZone = "";
            root._dragSource.hoverTargetIndex = -1;
        }
        root._dragSource = null;
    }

    // 1. Green line overlay for all edge split drops (both leaf split edges and root screen edges)
    Rectangle {
        id: greenLineOverlay
        readonly property bool isEdgeZone: root.hoverZone !== "" && root.hoverZone !== "center"
        visible: root.containsDrag && isEdgeZone
        color: root.colors.positiveTextColor
        opacity: 0.85
        border.color: root.colors.positiveTextColor
        border.width: 1

        x: {
            if (root.hoverZone === "root-right" || root.hoverZone === "root-drawer-right")
                return root.controller ? root.controller.mapToItem(root, 0, 0).x + root.controller.width - 6 : 0;
            if (root.hoverZone === "root-left" || root.hoverZone === "root-drawer-left")
                return root.controller ? root.controller.mapToItem(root, 0, 0).x : 0;
            if (root.hoverZone === "right" || root.hoverZone === "drawer-right")
                return root.width - 6;
            if (root.hoverZone === "left" || root.hoverZone === "drawer-left")
                return 0;
            return (root.hoverZone.indexOf("root-") === 0 && root.controller) ? root.controller.mapToItem(root, 0, 0).x : 0;
        }
        y: {
            if (root.hoverZone === "root-bottom" || root.hoverZone === "root-drawer-bottom")
                return root.controller ? root.controller.mapToItem(root, 0, 0).y + root.controller.height - 6 : 0;
            if (root.hoverZone === "root-top" || root.hoverZone === "root-drawer-top")
                return root.controller ? root.controller.mapToItem(root, 0, 0).y : 0;
            if (root.hoverZone === "bottom" || root.hoverZone === "drawer-bottom")
                return root.height - 6;
            if (root.hoverZone === "top" || root.hoverZone === "drawer-top")
                return 0;
            return (root.hoverZone.indexOf("root-") === 0 && root.controller) ? root.controller.mapToItem(root, 0, 0).y : 0;
        }
        width: {
            if (root.hoverZone === "root-left" || root.hoverZone === "root-right" || root.hoverZone === "root-drawer-left" || root.hoverZone === "root-drawer-right")
                return 6;
            if (root.hoverZone === "left" || root.hoverZone === "right" || root.hoverZone === "drawer-left" || root.hoverZone === "drawer-right")
                return 6;
            if (root.hoverZone.indexOf("root-") === 0 && root.controller)
                return root.controller.width;
            return root.width;
        }
        height: {
            if (root.hoverZone === "root-top" || root.hoverZone === "root-bottom" || root.hoverZone === "root-drawer-top" || root.hoverZone === "root-drawer-bottom")
                return 6;
            if (root.hoverZone === "top" || root.hoverZone === "bottom" || root.hoverZone === "drawer-top" || root.hoverZone === "drawer-bottom")
                return 6;
            if (root.hoverZone.indexOf("root-") === 0 && root.controller)
                return root.controller.height;
            return root.height;
        }
    }

    // 2. Blue area overlay for center zone (tab integration)
    Rectangle {
        id: blueAreaOverlay
        visible: root.containsDrag && root.hoverZone === "center"
        color: Qt.rgba(0.18, 0.48, 0.92, 0.35)
        border.color: Qt.rgba(0.25, 0.6, 1.0, 0.9)
        border.width: 2

        anchors.fill: parent
    }
}
