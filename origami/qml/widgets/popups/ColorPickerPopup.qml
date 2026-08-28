import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Full color picker popup with preset swatch palette, HSV sliders, hex field, and preview.
QQC2.Popup {
    id: popup

    property color selectedColor: "#3b82f6"

    signal colorAccepted(color color)

    // Internal HSV state
    property real _hue: 0.6
    property real _saturation: 0.8
    property real _value: 0.9

    readonly property var presetColors: ["#ef4444", "#f97316", "#f59e0b", "#10b981", "#06b6d4", "#3b82f6", "#6366f1", "#8b5cf6", "#ec4899", "#f43f5e", "#1e293b", "#475569", "#94a3b8", "#e2e8f0", "#ffffff"]

    function _syncHsvFromColor(c) {
        var r = c.r, g = c.g, b = c.b;
        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var d = max - min;
        popup._value = max;
        popup._saturation = max === 0 ? 0 : d / max;
        if (max === min) {
            popup._hue = 0;
        } else {
            if (max === r)
                popup._hue = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g)
                popup._hue = (b - r) / d + 2;
            else if (max === b)
                popup._hue = (r - g) / d + 4;
            popup._hue /= 6;
        }
    }

    onSelectedColorChanged: {
        _syncHsvFromColor(selectedColor);
        hexField.text = selectedColor.toString();
    }

    Component.onCompleted: {
        _syncHsvFromColor(selectedColor);
        hexField.text = selectedColor.toString();
    }

    ColumnLayout {
        spacing: StyleKit.Units.smallSpacing

        Origami.Label {
            font.bold: true
            text: "Color Picker"
        }

        // Color preview bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: StyleKit.Units.gridUnit * 1.5
            radius: StyleKit.Units.cornerRadius
            color: popup.selectedColor
            border.width: StyleKit.Units.borderWidth
            border.color: StyleKit.Theme.solidOutlineColor(popup.selectedColor)
        }

        // Preset palette swatches
        GridLayout {
            columns: 5
            rowSpacing: StyleKit.Units.smallSpacing / 2
            columnSpacing: StyleKit.Units.smallSpacing / 2

            Repeater {
                model: popup.presetColors

                delegate: Rectangle {
                    required property string modelData
                    width: StyleKit.Units.gridUnit * 1.2
                    height: StyleKit.Units.gridUnit * 1.2
                    radius: StyleKit.Units.cornerRadius / 2
                    color: modelData
                    border.width: popup.selectedColor.toString() === modelData ? 2 : 1
                    border.color: popup.selectedColor.toString() === modelData ? popup.colors.highlightColor : StyleKit.Theme.solidOutlineColor(Qt.color(modelData))

                    TapHandler {
                        onTapped: {
                            popup.selectedColor = parent.modelData;
                        }
                    }
                }
            }
        }

        Origami.Separator {
            Layout.fillWidth: true
        }

        // Sliders for Hue, Saturation, Value
        RowLayout {
            spacing: StyleKit.Units.smallSpacing
            Origami.Label {
                text: "H"
                Layout.preferredWidth: StyleKit.Units.gridUnit * 0.8
            }
            Origami.Slider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: popup._hue
                onValueChangeRequested: v => {
                    popup._hue = v;
                    popup.selectedColor = Qt.hsva(popup._hue, popup._saturation, popup._value, 1.0);
                }
            }
        }

        RowLayout {
            spacing: StyleKit.Units.smallSpacing
            Origami.Label {
                text: "S"
                Layout.preferredWidth: StyleKit.Units.gridUnit * 0.8
            }
            Origami.Slider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: popup._saturation
                onValueChangeRequested: v => {
                    popup._saturation = v;
                    popup.selectedColor = Qt.hsva(popup._hue, popup._saturation, popup._value, 1.0);
                }
            }
        }

        RowLayout {
            spacing: StyleKit.Units.smallSpacing
            Origami.Label {
                text: "V"
                Layout.preferredWidth: StyleKit.Units.gridUnit * 0.8
            }
            Origami.Slider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: popup._value
                onValueChangeRequested: v => {
                    popup._value = v;
                    popup.selectedColor = Qt.hsva(popup._hue, popup._saturation, popup._value, 1.0);
                }
            }
        }

        // Hex Code Field
        RowLayout {
            spacing: StyleKit.Units.smallSpacing
            Origami.Label {
                text: "Hex"
            }
            QQC2.TextField {
                id: hexField
                Layout.fillWidth: true
                text: popup.selectedColor.toString()
                onEditingFinished: {
                    var parsed = Qt.color(hexField.text);
                    if (parsed.toString() !== "#000000" || hexField.text === "#000000" || hexField.text === "black") {
                        popup.selectedColor = parsed;
                    }
                }
            }
        }

        // Action Buttons
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: StyleKit.Units.smallSpacing

            Origami.ActionButton {
                text: "Cancel"
                onClicked: popup.close()
            }

            Origami.ActionButton {
                text: "OK"
                highlighted: true
                onClicked: {
                    popup.colorAccepted(popup.selectedColor);
                    popup.close();
                }
            }
        }
    }
}
