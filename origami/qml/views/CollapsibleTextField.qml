import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Collapsible icon + text field -- e.g. a search box or a path/address entry.
Item {
    id: root

    property string iconName: ""
    property string placeholderText: ""
    property alias text: inputField.text

    signal accepted

    readonly property real squareSize: StyleKit.Units.gridUnit * 1.6
    readonly property real comfortableWidth: StyleKit.Units.gridUnit * 6
    readonly property bool collapsed: root.width <= root.comfortableWidth
    readonly property real expandedIconInset: (root.squareSize - StyleKit.Units.iconSizes.small) / 2
    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    implicitHeight: root.squareSize
    Layout.minimumWidth: root.squareSize

    Rectangle {
        id: frame
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.collapsed ? root.squareSize : parent.width
        radius: StyleKit.Units.cornerRadius
        color: (root.collapsed && collapsedHover.hovered) ? root.colors.hoverColor : root.colors.backgroundColor
        border.width: StyleKit.Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3)

        Item {
            id: expandedContent
            anchors.fill: parent
            visible: !root.collapsed

            Origami.Icon {
                id: expandedIcon
                visible: root.iconName !== ""
                anchors.left: parent.left
                anchors.leftMargin: root.expandedIconInset
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconName
                color: root.colors.textColor
                width: StyleKit.Units.iconSizes.small
                height: StyleKit.Units.iconSizes.small
            }

            QQC2.TextField {
                id: inputField
                anchors.left: expandedIcon.visible ? expandedIcon.right : parent.left
                anchors.leftMargin: expandedIcon.visible ? StyleKit.Units.smallSpacing : root.expandedIconInset
                anchors.right: parent.right
                anchors.rightMargin: StyleKit.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: root.placeholderText
                color: root.colors.textColor
                placeholderTextColor: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.5)
                background: null
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                onAccepted: root.accepted()
            }
        }

        Origami.Icon {
            visible: root.collapsed && root.iconName !== ""
            anchors.centerIn: frame
            source: root.iconName
            color: root.colors.textColor
            width: StyleKit.Units.iconSizes.small
            height: StyleKit.Units.iconSizes.small
        }

        HoverHandler {
            id: collapsedHover
            enabled: root.collapsed
        }

        TapHandler {
            enabled: root.collapsed
            onTapped: {
                collapsedPopup.open();
                collapsedPopup.contentItem.forceActiveFocus();
            }
        }

        QQC2.Popup {
            id: collapsedPopup
            parent: frame
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
            x: 0
            y: frame.height + StyleKit.Units.smallSpacing
            width: StyleKit.Units.gridUnit * 12

            contentItem: QQC2.TextField {
                placeholderText: root.placeholderText
                text: root.text
                color: root.colors.textColor
                placeholderTextColor: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.5)
                background: null
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                onTextChanged: root.text = text
                onAccepted: {
                    root.accepted();
                    collapsedPopup.close();
                }
            }
        }
    }
}
