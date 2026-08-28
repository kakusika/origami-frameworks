import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// A generic confirmation / message dialog popup.
// Provides standard title, message, confirm/cancel buttons, and destructive action styling.
Origami.ModalDialog {
    id: root

    title: "Confirm Action"
    property string message: "Are you sure you want to proceed?"
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool isDestructive: false
    property bool showCancel: true

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    signal confirmed
    signal cancelled

    Origami.Label {
        text: root.message
        type: "secondary"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Origami.Separator {
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.alignment: Qt.AlignRight
        spacing: StyleKit.Units.smallSpacing

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
                radius: StyleKit.Units.cornerRadius
                color: root.isDestructive ? root.colors.negativeTextColor : root.colors.highlightColor
            }
            onClicked: {
                root.confirmed();
                root.close();
            }
        }
    }
}
