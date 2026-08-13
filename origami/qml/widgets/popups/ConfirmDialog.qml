import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

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

    readonly property var colors: Theme.paletteFor(Theme.view)

    signal confirmed
    signal cancelled

    ColumnLayout {
        spacing: Units.largeSpacing
        implicitWidth: Units.gridUnit * 16

        Label {
            font.bold: true
            font.pointSize: Units.gridUnit * 0.75
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
            spacing: Units.smallSpacing

            ActionButton {
                visible: root.showCancel
                text: root.cancelText
                onClicked: {
                    root.cancelled();
                    root.close();
                }
            }

            ActionButton {
                text: root.confirmText
                highlighted: true
                // Render negative/danger highlight if destructive
                background: Rectangle {
                    radius: Units.cornerRadius
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
