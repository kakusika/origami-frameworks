import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0

// Blender-style dockable side panel: shows arbitrary content when expanded,
// and collapses to a thin strip with a single arrow button when hidden.
// Usage:
//
//   CollapsiblePanel {
//       anchors.top: parent.top
//       anchors.right: parent.right
//       anchors.margins: 12
//       panelWidth: 220
//
//       Label { text: "..." }
//       Slider { ... }
//   }
//
// Children assigned directly (the default property) are laid out in a
// ColumnLayout inside the panel body.
Item {
    id: root

    // Which edge of the parent this panel is docked to. Determines which
    // side the collapse/expand arrow points to. Qt.RightEdge or Qt.LeftEdge.
    property int edge: Qt.RightEdge
    property bool expanded: true
    property real panelWidth: 220

    // `view` (not `header`/`window`) since this floats directly over a
    // view's own content (map tiles, a node graph, ...) -- same colorSet
    // PaneDrawer.qml's own translucent body background uses. Kept as plain
    // `property color` (not `readonly`) so a caller can still override
    // either, same as before this tracked the theme.
    readonly property var colors: Theme.paletteFor(Theme.view)
    property color panelColor: Qt.rgba(root.colors.backgroundColor.r, root.colors.backgroundColor.g, root.colors.backgroundColor.b, 0.8)
    property color handleColor: root.panelColor

    readonly property bool dockedRight: edge === Qt.RightEdge

    default property alias content: contentColumn.data

    implicitWidth: expanded ? panelWidth : collapsedHandle.implicitWidth
    implicitHeight: expanded ? panelBody.implicitHeight : collapsedHandle.implicitHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

    // Collapsed: a small edge tab with a single arrow button that re-expands
    // the panel, mirroring Blender's collapsed sidebar handle.
    IconButton {
        id: collapsedHandle
        visible: !root.expanded
        anchors.top: parent.top
        anchors.right: root.dockedRight ? parent.right : undefined
        anchors.left: root.dockedRight ? undefined : parent.left
        onClicked: root.expanded = true

        iconName: root.dockedRight ? "arrow-left" : "arrow-right"

        background: Rectangle {
            color: root.handleColor
            radius: Units.cornerRadius
        }
    }

    // Expanded: the panel body, with a collapse button pinned to the edge
    // closest to the parent's border, and the caller-supplied content below.
    Rectangle {
        id: panelBody
        visible: root.expanded
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: contentColumn.implicitHeight + collapseButton.height + 16
        color: root.panelColor
        radius: Units.cornerRadius

        IconButton {
            id: collapseButton
            anchors.top: parent.top
            anchors.right: root.dockedRight ? parent.right : undefined
            anchors.left: root.dockedRight ? undefined : parent.left
            onClicked: root.expanded = false

            iconName: root.dockedRight ? "arrow-right" : "arrow-left"
        }

        ColumnLayout {
            id: contentColumn
            anchors.top: collapseButton.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Units.smallSpacing
            spacing: Units.smallSpacing
        }
    }
}
