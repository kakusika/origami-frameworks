import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Segmented row of independent action buttons.
Item {
    id: root

    property var actions: []
    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: "transparent"
        border.width: StyleKit.Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3)
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.actions

            QQC2.ToolButton {
                id: actionButton
                required property var modelData
                required property int index

                readonly property bool _enabled: modelData.enabled !== false
                enabled: actionButton._enabled

                implicitWidth: StyleKit.Units.iconSizes.smallMedium + StyleKit.Units.largeSpacing
                implicitHeight: StyleKit.Units.gridUnit * 1.6

                opacity: actionButton._enabled ? 1 : 0.4

                contentItem: Origami.Icon {
                    anchors.centerIn: parent
                    color: root.colors.textColor
                    source: actionButton.modelData.iconName || ""
                    width: StyleKit.Units.iconSizes.smallMedium
                    height: StyleKit.Units.iconSizes.smallMedium
                }

                background: Rectangle {
                    topLeftRadius: actionButton.index === 0 ? StyleKit.Units.cornerRadius : 0
                    bottomLeftRadius: actionButton.index === 0 ? StyleKit.Units.cornerRadius : 0
                    topRightRadius: actionButton.index === root.actions.length - 1 ? StyleKit.Units.cornerRadius : 0
                    bottomRightRadius: actionButton.index === root.actions.length - 1 ? StyleKit.Units.cornerRadius : 0
                    color: (actionButton.hovered && actionButton._enabled) ? root.colors.hoverColor : "transparent"

                    Rectangle {
                        visible: actionButton.index > 0
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
                    }
                }

                onClicked: {
                    if (actionButton.modelData.onTriggered) {
                        actionButton.modelData.onTriggered();
                    }
                }
            }
        }
    }
}
