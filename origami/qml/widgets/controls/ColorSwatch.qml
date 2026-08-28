import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// A Blender-style color swatch button. Displays a small colored rectangle preview,
// an optional text label, and opens a ColorPickerPopup on click.
Item {
    id: root

    property color selectedColor: "#3b82f6"
    property string label: ""

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    signal colorPicked(color color)

    implicitWidth: label.length > 0 ? StyleKit.Units.gridUnit * 7 : StyleKit.Units.gridUnit * 2.2
    implicitHeight: StyleKit.Units.gridUnit * 1.6

    Rectangle {
        id: container
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: hoverHandler.hovered ? root.colors.hoverColor : "transparent"
        border.width: StyleKit.Units.borderWidth
        border.color: StyleKit.Theme.opaqueBlend(root.colors.textColor, root.colors.backgroundColor, 0.25)

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
            anchors.margins: StyleKit.Units.smallSpacing / 2
            spacing: StyleKit.Units.smallSpacing

            Rectangle {
                Layout.preferredWidth: StyleKit.Units.gridUnit * 1.2
                Layout.preferredHeight: StyleKit.Units.gridUnit * 1.2
                radius: StyleKit.Units.cornerRadius / 2
                color: root.selectedColor
                border.width: 1
                border.color: StyleKit.Theme.solidOutlineColor(root.selectedColor)
            }

            Origami.Label {
                visible: root.label.length > 0
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: root.label
            }

            Origami.Icon {
                source: "chevron-down"
                width: StyleKit.Units.iconSizes.small
                height: StyleKit.Units.iconSizes.small
                color: root.colors.textColor
                opacity: 0.6
            }
        }
    }

    Origami.ColorPickerPopup {
        id: pickerPopup
        selectedColor: root.selectedColor
        onColorAccepted: col => {
            root.selectedColor = col;
            root.colorPicked(col);
        }
    }
}
