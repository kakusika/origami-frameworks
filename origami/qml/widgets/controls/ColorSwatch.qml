import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

// A Blender-style color swatch button. Displays a small colored rectangle preview,
// an optional text label, and opens a ColorPickerPopup on click.
Item {
    id: root

    property color selectedColor: "#3b82f6"
    property string label: ""

    readonly property var colors: Theme.paletteFor(Theme.view)

    signal colorPicked(color color)

    implicitWidth: label.length > 0 ? Units.gridUnit * 7 : Units.gridUnit * 2.2
    implicitHeight: Units.gridUnit * 1.6

    Rectangle {
        id: container
        anchors.fill: parent
        radius: Units.cornerRadius
        color: hoverHandler.hovered ? root.colors.hoverColor : "transparent"
        border.width: Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.25)

        HoverHandler {
            id: hoverHandler
            enabled: root.enabled
        }

        TapHandler {
            enabled: root.enabled
            onTapped: pickerPopup.open()
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Units.smallSpacing / 2
            spacing: Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: Units.gridUnit * 1.2
                Layout.preferredHeight: Units.gridUnit * 1.2
                radius: Units.cornerRadius / 2
                color: root.selectedColor
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
            }

            Label {
                visible: root.label.length > 0
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.label
            }

            Icon {
                source: "arrow-down-symbolic"
                width: Units.iconSizes.small
                height: Units.iconSizes.small
                color: root.colors.textColor
                opacity: 0.6
            }
        }
    }

    ColorPickerPopup {
        id: pickerPopup
        selectedColor: root.selectedColor
        onColorAccepted: col => {
            root.selectedColor = col;
            root.colorPicked(col);
        }
    }
}
