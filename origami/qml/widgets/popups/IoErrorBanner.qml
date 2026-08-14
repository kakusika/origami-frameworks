import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami

// Dismissible strip for the `io_error` qproperty pattern shared by every
// JSON save/load-backed view model (CalendarModel, BoardState,
// TimelineState): a thin red banner with the error text and a close
// button, visible only while there's a message. Unlike qml-embed's
// full-cover error overlay (QmlView.qml), a failed save/load shouldn't
// block interacting with whatever content is already loaded, so this only
// ever covers a thin strip.
//
// Positioning (anchored overlay strip pinned to the top vs. an in-flow
// Layout child at the bottom) is the caller's responsibility -- Board/
// Timeline anchor this to the top with z: 10 over their paint item;
// Calendar places it as the last child of a ColumnLayout instead.
//
// Colors come from Theme.negativeTextColor (the same semantic "error" red
// SettingsPage.qml/etc. would use) rather than a banner-specific literal,
// so this stays visually consistent with the rest of the app's error
// styling and with whatever light/dark mode is active.
Rectangle {
    id: root

    property alias message: errorLabel.text
    signal dismissed

    // Also surfaces to the status bar's transient error area (see
    // ErrorBus.qml) alongside this banner, so a save/load failure is
    // noticed even if this banner isn't currently in view.
    onMessageChanged: if (root.message.length > 0)
        Origami.ErrorBus.reportError(root.message)

    height: errorLabel.implicitHeight + 16
    visible: message.length > 0
    color: Qt.rgba(Origami.Theme.negativeTextColor.r, Origami.Theme.negativeTextColor.g, Origami.Theme.negativeTextColor.b, 0.25)

    QQC2.Label {
        id: errorLabel
        anchors.left: parent.left
        anchors.right: closeErrorButton.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Origami.Units.smallSpacing
        type: "negative"
        wrapMode: Text.Wrap
    }

    QQC2.ToolButton {
        id: closeErrorButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "×"

        // Explicit background/contentItem (Theme-driven, flat hover
        // fill) rather than the active QQC2 style's own ToolButton
        // chrome -- same reasoning as every other de-Breezed button in
        // origami (see Button.qml's class comment); this banner's own
        // color already comes from Theme.negativeTextColor, so its close
        // button should too rather than mismatching in native gray.
        background: Rectangle {
            radius: Origami.Units.cornerRadius
            color: closeErrorButton.hovered ? Qt.rgba(Origami.Theme.negativeTextColor.r, Origami.Theme.negativeTextColor.g, Origami.Theme.negativeTextColor.b, 0.2) : "transparent"
        }

        contentItem: QQC2.Label {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: closeErrorButton.text
            color: Origami.Theme.negativeTextColor
        }

        onClicked: root.dismissed()
    }
}
