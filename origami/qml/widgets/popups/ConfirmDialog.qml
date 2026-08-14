import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami

// A generic confirmation / message dialog popup.
// Provides standard title, message, confirm/cancel buttons, and destructive action styling.
QQC2.Popup {
    id: root

    property string title: "Confirm Action"
    property string message: "Are you sure you want to proceed?"
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool isDestructive: false
    property bool showCancel: true

    readonly property var colors: Origami.Theme.paletteFor(Origami.Theme.view)

    signal confirmed
    signal cancelled

    ColumnLayout {
        spacing: Origami.Units.largeSpacing
        implicitWidth: Origami.Units.gridUnit * 16

        Label {
            font.bold: true
            font.pointSize: Origami.Units.gridUnit * 0.75
            text: root.title
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Label {
            text: root.message
            type: "secondary"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Origami.Units.smallSpacing

            Origami.ActionButton {
                visible: root.showCancel
                text: root.cancelText
                onClicked: {
                    root.cancelled();
                    root.close();
                }
            }

            Origami.ActionButton {
                text: root.confirmText
                highlighted: true
                // Render negative/danger highlight if destructive
                background: Rectangle {
                    radius: Origami.Units.cornerRadius
                    color: root.isDestructive ? root.colors.negativeTextColor : root.colors.highlightColor
                }
                onClicked: {
                    root.confirmed();
                    root.close();
                }
            }
        }
    }
}
