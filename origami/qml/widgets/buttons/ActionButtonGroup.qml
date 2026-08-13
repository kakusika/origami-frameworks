import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami

// Segmented row of independent action buttons.
Item {
    id: root

    property var actions: []
    readonly property var colors: Origami.Theme.paletteFor(Origami.Theme.header)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Origami.Units.cornerRadius
        color: "transparent"
        border.width: Origami.Units.borderWidth
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

                implicitWidth: Origami.Units.iconSizes.smallMedium + Origami.Units.largeSpacing
                implicitHeight: Origami.Units.gridUnit * 1.6

                opacity: actionButton._enabled ? 1 : 0.4

                contentItem: Origami.Icon {
                    anchors.centerIn: parent
                    color: root.colors.textColor
                    source: actionButton.modelData.iconName || ""
                    width: Origami.Units.iconSizes.smallMedium
                    height: Origami.Units.iconSizes.smallMedium
                }

                background: Rectangle {
                    topLeftRadius: actionButton.index === 0 ? Origami.Units.cornerRadius : 0
                    bottomLeftRadius: actionButton.index === 0 ? Origami.Units.cornerRadius : 0
                    topRightRadius: actionButton.index === root.actions.length - 1 ? Origami.Units.cornerRadius : 0
                    bottomRightRadius: actionButton.index === root.actions.length - 1 ? Origami.Units.cornerRadius : 0
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
