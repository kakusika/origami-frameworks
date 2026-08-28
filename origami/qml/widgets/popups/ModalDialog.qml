import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Shared chrome for a modal prompt/dialog popup: modal/focus/Escape-close
// flags, centered positioning, a bold title Label, and a content slot for
// everything below it (message text, form fields, a Separator, a button
// row -- whatever the composing dialog needs). Composed by ConfirmDialog.qml
// (simple declarative confirm/cancel) and by per-feature dialogs like
// explorer's RenameDialog.qml (imperative showFor()/reportResult()
// instances with their own content) -- see both for usage.
//
// Deliberately just a reusable base component, not a stack/manager
// singleton: callers instantiate and open() it themselves, same spirit as
// the ConfirmDialog.qml precedent this replaces the shell of.
//
// No separate footer/button-row slot: ConfirmDialog's and RenameDialog's
// button rows differ enough (destructive-color background override vs. an
// _accept()-wired pair) that forcing them through one shared slot buys
// little and would collide with QML's one-default-property-per-type limit.
// Composing dialogs declare their own Separator + button RowLayout as part
// of `content`, same as they already did before this existed.
QQC2.Popup {
    id: root

    modal: true
    focus: true
    anchors.centerIn: parent
    closePolicy: QQC2.Popup.CloseOnEscape

    property string title: ""
    property real dialogWidth: StyleKit.Units.gridUnit * 16

    default property alias content: contentArea.data

    ColumnLayout {
        spacing: StyleKit.Units.largeSpacing
        implicitWidth: root.dialogWidth

        Origami.Label {
            font.bold: true
            font.pointSize: StyleKit.Units.gridUnit * 0.75
            text: root.title
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        ColumnLayout {
            id: contentArea
            Layout.fillWidth: true
            spacing: StyleKit.Units.largeSpacing
        }
    }
}
