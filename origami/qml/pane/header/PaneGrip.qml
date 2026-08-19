import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Standalone drag-handle component for node/pane moving in the pane tree.
// Encapsulates the visual 6-dot grip (DragHandle) and all D&D drag/drop
// mechanics (MouseArea, dragProxy, beginDrag/endDrag, requestDrop/extractTab/insertTab),
// decoupled entirely from PaneTabHeader.qml.
Item {
    id: root
    property string title: ""
    property int tabId: -1
    property int leafId: -1
    property var controller

    // Orientation of the 6-dot grip: false = vertical (2x3 grid), true = horizontal (3x2 grid)
    property bool horizontal: false

    property real dragThreshold: Qt.styleHints.startDragDistance
    property bool _hovered: false

    signal clicked
    signal closeRequested

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    implicitWidth: dotGrid.implicitWidth + StyleKit.Units.smallSpacing * 2
    implicitHeight: dotGrid.implicitHeight + StyleKit.Units.smallSpacing * 2

    // Background hover highlight
    Rectangle {
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: root._hovered ? root.colors.hoverColor : "transparent"
    }

    HoverHandler {
        onHoveredChanged: root._hovered = hovered
    }

    // Visual dot grid
    Origami.DragHandle {
        id: dotGrid
        anchors.centerIn: parent
        horizontal: root.horizontal
        color: root.colors.textColor
    }

    Origami.ThemedMenu {
        id: contextMenu

        menuItems: [
            {
                text: "閉じる",
                onTriggered: function () {
                    root.closeRequested();
                }
            }
        ]
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true

        property real _pressX: 0
        property real _pressY: 0
        property bool _dragging: false

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup();
                return;
            }
            dragArea._pressX = mouse.x;
            dragArea._pressY = mouse.y;
            dragArea._dragging = false;
        }
        onPositionChanged: mouse => {
            if (!dragArea.pressed || (mouse.buttons & Qt.LeftButton) === 0)
                return;
            if (!dragArea._dragging) {
                if (root.controller && root.controller.layoutLocked)
                    return;
                var dx = mouse.x - dragArea._pressX;
                var dy = mouse.y - dragArea._pressY;
                if (Math.hypot(dx, dy) < root.dragThreshold)
                    return;
                dragArea._dragging = true;
                root.controller.beginDrag(root, dragProxy, mouse.x, mouse.y);
            } else {
                var pos = dragArea.mapToItem(root.controller.dragLayer, mouse.x, mouse.y);
                dragProxy.x = pos.x;
                dragProxy.y = pos.y;
            }
        }
        onReleased: {
            if (dragArea._dragging) {
                var targetController = dragProxy.hoverController;
                var targetLeafId = dragProxy.hoverLeafId;
                var zone = dragProxy.hoverZone || "center";
                if (targetController && targetLeafId >= 0) {
                    if (targetController === root.controller) {
                        targetController.requestDrop(root.leafId, root.tabId, targetLeafId, zone);
                    } else {
                        var tabData = root.controller.extractTab(root.leafId, root.tabId);
                        if (tabData)
                            targetController.insertTab(tabData, targetLeafId, zone);
                    }
                }
                dragProxy.hoverController = null;
                dragProxy.hoverLeafId = -1;
                dragProxy.hoverZone = "";
                dragProxy.x = -100000;
                dragProxy.y = -100000;
                root.controller.endDrag(dragProxy);
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !dragArea._dragging)
                root.clicked();
            dragArea._dragging = false;
        }
        onCanceled: {
            dragProxy.hoverController = null;
            dragProxy.hoverLeafId = -1;
            dragProxy.hoverZone = "";
            dragProxy.x = -100000;
            dragProxy.y = -100000;
            dragArea._dragging = false;
            root.controller.endDrag(dragProxy);
        }

        Item {
            id: dragProxy
            parent: root.controller ? root.controller.dragLayer : root
            visible: false
            width: 1
            height: 1
            z: 1000

            readonly property int tabId: root.tabId
            readonly property int leafId: root.leafId

            property var hoverController: null
            property int hoverLeafId: -1
            property string hoverZone: ""

            Drag.dragType: Drag.Internal
            Drag.active: dragArea._dragging
            Drag.keys: ["pane-tab"]

            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 28
                radius: StyleKit.Units.cornerRadius
                color: root.colors.backgroundColor
                border.color: root.colors.highlightColor
                border.width: 1
                opacity: 0.85

                Text {
                    anchors.centerIn: parent
                    text: root.title
                    color: root.colors.textColor
                    elide: Text.ElideRight
                    width: parent.width - StyleKit.Units.smallSpacing * 2
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
