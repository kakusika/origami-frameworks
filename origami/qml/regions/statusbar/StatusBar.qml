import QtQuick
import la.cettila.Origami 1.0

// Window-wide bar shell, fixed to the bottom. A themed HeaderBar wrapper
// (see HeaderBar.qml's own class comment for the generic start/center/end
// mechanism this passes straight through) that adds only what any status
// bar needs regardless of what it shows: the themed background and the
// separator against PaneView above it. Whether it's shown at all is up to
// the caller too -- this component has no settings/persistence knowledge
// of its own, it just exposes `statusBarVisible` (default true) for the
// consuming app to bind to whatever show/hide-on-startup setting it has
// (see the consuming app's own StatusBar {} usage for that, and
// SettingsPage.qml's appearance/status-bar section for where that setting
// lives). What actually goes in start/center/end is entirely up to the
// caller too -- this component knows nothing about errors, performance
// stats, or any other concrete content.
Rectangle {
    id: root

    property list<QtObject> start
    property list<QtObject> center
    property list<QtObject> end

    // Whether the bar should be shown. Left to the caller to bind from
    // whatever persisted setting (if any) it has; defaults to visible so
    // this component is usable standalone with no wiring at all.
    property bool statusBarVisible: true

    readonly property var colors: Theme.paletteFor(Theme.header)
    color: root.colors.backgroundColor

    // Collapsing height to 0 when hidden, rather than a separate main.qml
    // change, is enough: main.qml's PaneView already derives its bottom
    // margin from `statusBar.height`.
    visible: root.statusBarVisible
    height: root.visible ? headerBar.height : 0
    implicitHeight: height

    // Separator against PaneView, which sits above this bar.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
    }

    HeaderBar {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        start: root.start
        center: root.center
        end: root.end
    }
}
