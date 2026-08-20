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
        if (drag.source && drag.source.leafId === root.leafId && root.controller && root.controller.isStandalonePane(root.leafId))
            return "";
        var raw = root._rawZoneFor(x, y);
        if (raw === "center" && root.controller && ((drag.source && root.controller.isToolbarPane(drag.source.leafId)) || root.controller.isToolbarPane(root.leafId)))
            return "";
        return raw;
    }

    readonly property real drawerEdge: 16

    function _rawZoneFor(x, y) {
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
        }
        root._dragSource = null;
    }

    // 1. Green line overlay for toolbar or drawer drops at split edges
    Rectangle {
        id: greenLineOverlay
        readonly property bool isLineZone: root.hoverZone === "drawer-top" || root.hoverZone === "drawer-bottom" || root.hoverZone === "drawer-left" || root.hoverZone === "drawer-right" || root.isDraggingToolbarOrDrawer
        visible: root.containsDrag && root.hoverZone !== "" && isLineZone
        color: root.colors.positiveTextColor
        opacity: 0.85
        border.color: root.colors.positiveTextColor
        border.width: 1

        x: {
            if (root.hoverZone === "drawer-right" || (root.isDraggingToolbarOrDrawer && root.hoverZone === "right"))
                return root.width - 6;
            if (root.hoverZone === "drawer-left" || (root.isDraggingToolbarOrDrawer && root.hoverZone === "left"))
                return 0;
            return 0;
        }
        y: {
            if (root.hoverZone === "drawer-bottom" || (root.isDraggingToolbarOrDrawer && root.hoverZone === "bottom"))
                return root.height - 6;
            if (root.hoverZone === "drawer-top" || (root.isDraggingToolbarOrDrawer && root.hoverZone === "top"))
                return 0;
            return 0;
        }
        width: {
            if (root.hoverZone === "drawer-left" || root.hoverZone === "drawer-right" || (root.isDraggingToolbarOrDrawer && (root.hoverZone === "left" || root.hoverZone === "right")))
                return 6;
            return root.width;
        }
        height: {
            if (root.hoverZone === "drawer-top" || root.hoverZone === "drawer-bottom" || (root.isDraggingToolbarOrDrawer && (root.hoverZone === "top" || root.hoverZone === "bottom")))
                return 6;
            return root.height;
        }
    }

    // 2. Blue area overlay for tabs and standard panes (covers about half area for split directions)
    Rectangle {
        id: blueAreaOverlay
        readonly property bool isLineZone: root.hoverZone === "drawer-top" || root.hoverZone === "drawer-bottom" || root.hoverZone === "drawer-left" || root.hoverZone === "drawer-right" || root.isDraggingToolbarOrDrawer
        visible: root.containsDrag && root.hoverZone !== "" && !isLineZone
        color: Qt.rgba(0.18, 0.48, 0.92, 0.35)
        border.color: Qt.rgba(0.25, 0.6, 1.0, 0.9)
        border.width: 2

        x: root.hoverZone === "right" ? root.width / 2 : 0
        y: root.hoverZone === "bottom" ? root.height / 2 : 0
        width: (root.hoverZone === "left" || root.hoverZone === "right") ? root.width / 2 : root.width
        height: (root.hoverZone === "top" || root.hoverZone === "bottom") ? root.height / 2 : root.height
    }
}
