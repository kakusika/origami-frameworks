import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

QQC2.ToolButton {
    id: root

    property string iconName: ""
    property int iconSize: StyleKit.Units.iconSizes.small
    property var menuItems: []

    onMenuItemsChanged: Qt.callLater(root._syncMenuItems)
    Component.onCompleted: root._syncMenuItems()

    function _syncMenuItems() {
        menu.menuItems = root.menuItems;
    }

    property real popupX: 0
    property real popupY: root.height

    property int colorSet: StyleKit.Theme.header
    readonly property var colors: StyleKit.Theme.paletteFor(root.colorSet)
    readonly property alias open: menu.visible

    signal opened
    signal closed

    function requestOpen() {
        menu.popup(root, root.popupX, root.popupY);
    }
    function requestClose() {
        menu.close();
    }

    // `checked` (not `checkable` -- nothing should auto-toggle it, only
    // this binding drives it) instead of a hand-painted highlight color:
    // the active QQC2 style already knows how to render a checked
    // toggle/tool button distinctly, so this keeps the "popup is open"
    // affordance without this component owning any background paint.
    checked: menu.visible

    implicitHeight: StyleKit.Units.gridUnit * 1.4
    implicitWidth: contentRow.implicitWidth + StyleKit.Units.largeSpacing + 4

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: StyleKit.Units.smallSpacing

            Origami.Icon {
                visible: root.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                color: root.colors.textColor
                source: root.iconName
                width: root.iconSize
                height: root.iconSize
            }

            Origami.Label {
                visible: root.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                color: root.colors.textColor
                text: root.text
            }
        }
    }

    onClicked: root.open ? root.requestClose() : root.requestOpen()

    Origami.ThemedMenu {
        id: menu
        onOpened: root.opened()
        onClosed: root.closed()
    }
}
