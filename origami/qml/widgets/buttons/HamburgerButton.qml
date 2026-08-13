import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

QQC2.ToolButton {
    id: root

    property string iconName: ""
    property int iconSize: Units.iconSizes.small
    property var menuItems: []

    onMenuItemsChanged: Qt.callLater(root._syncMenuItems)
    Component.onCompleted: root._syncMenuItems()

    function _syncMenuItems() {
        menu.menuItems = root.menuItems;
    }

    property real popupX: 0
    property real popupY: root.height

    property int colorSet: Theme.header
    readonly property var colors: Theme.paletteFor(root.colorSet)
    readonly property alias open: menu.visible

    signal opened
    signal closed

    function requestOpen() {
        menu.popup(root, root.popupX, root.popupY);
    }
    function requestClose() {
        menu.close();
    }

    background: Rectangle {
        radius: Units.cornerRadius
        color: menu.visible ? root.colors.highlightColor : (root.hovered ? root.colors.hoverColor : root.colors.backgroundColor)
        border.width: Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3)
    }

    implicitHeight: Units.gridUnit * 1.4
    implicitWidth: contentRow.implicitWidth + Units.largeSpacing + 4

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Units.smallSpacing

            Icon {
                visible: root.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                color: root.colors.textColor
                source: root.iconName
                width: root.iconSize
                height: root.iconSize
            }

            Label {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                color: root.colors.textColor
                text: root.text
            }
        }
    }

    onClicked: root.open ? root.requestClose() : root.requestOpen()

    ThemedMenu {
        id: menu
        onOpened: root.opened()
        onClosed: root.closed()
    }
}
