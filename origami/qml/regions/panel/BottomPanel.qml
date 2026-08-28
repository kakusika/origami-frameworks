import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Bottom panel floating or docked at the bottom of a view:
// shows arbitrary content when expanded, and collapses to a handle
// button on the left when hidden (mirroring CollapsiblePanel.qml).
Item {
    id: root

    property bool expanded: true
    property real panelWidth: 340

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)
    property color panelColor: Qt.rgba(root.colors.backgroundColor.r, root.colors.backgroundColor.g, root.colors.backgroundColor.b, 0.9)
    property color handleColor: root.panelColor

    default property alias content: contentColumn.data

    implicitWidth: expanded ? Math.min(parent ? parent.width - 12 : panelWidth, panelWidth) : collapsedHandle.implicitWidth
    implicitHeight: expanded ? panelBody.implicitHeight + (toggleButton.visible ? toggleButton.implicitHeight + 4 : 0) : collapsedHandle.implicitHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

    // Collapsed: handle button on the bottom left
    Origami.IconButton {
        id: collapsedHandle
        visible: !root.expanded
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        onClicked: root.expanded = true

        iconName: "chevron-up"

        background: Rectangle {
            color: root.handleColor
            radius: StyleKit.Units.cornerRadius
        }
    }

    // Expanded: toggle button placed OUTSIDE the main content panel on the left side
    Origami.IconButton {
        id: toggleButton
        visible: root.expanded
        anchors.bottom: panelBody.top
        anchors.left: panelBody.left
        anchors.bottomMargin: 4
        onClicked: root.expanded = false

        iconName: "chevron-down"

        background: Rectangle {
            color: root.handleColor
            radius: StyleKit.Units.cornerRadius
        }
    }

    // Expanded: main content body rectangle
    Rectangle {
        id: panelBody
        visible: root.expanded
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: contentColumn.implicitHeight + StyleKit.Units.smallSpacing * 2
        color: root.panelColor
        radius: StyleKit.Units.cornerRadius
        border.width: 1
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: StyleKit.Units.smallSpacing
            spacing: StyleKit.Units.smallSpacing
        }
    }
}
