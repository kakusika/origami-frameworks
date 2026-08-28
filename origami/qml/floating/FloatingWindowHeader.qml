import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Window-chrome titlebar for FloatingWindow.qml: title, minimize, maximize/
// restore, close, and drag-to-reposition -- purely "control this window as
// a window" concerns, nothing pane-specific. The pane itself gets its own
// second header row directly in FloatingWindow.qml (a real
// Origami.PaneHeader, wired against FloatingWindow's own controller-shim
// -- grip, view-type switcher, menus, all of it, exactly like a docked
// pane's). This file deliberately does not duplicate any of that -- this
// codebase settles on exactly two header shapes, docked (PaneHeader.qml)
// and floating-window-chrome (this), not a third hybrid.
Rectangle {
    id: root

    // The FloatingWindow this header belongs to -- called directly for
    // bringToFront()/x/y (reposition drag) and toggleMinimize()/
    // toggleMaximize() (button clicks) rather than round-tripping through
    // signals, since this header has no reason to be usable without one.
    required property Item windowItem

    property string title: ""
    property bool closable: true
    // Inputs only (state lives on windowItem) -- drive icon swap
    // (maximize/restore) and cross-disable (can't maximize while
    // minimized or vice versa; see windowItem's own toggle functions).
    property bool minimized: false
    property bool maximized: false

    readonly property var _headerColors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    height: StyleKit.Units.gridUnit * 1.8
    radius: StyleKit.Units.cornerRadius
    color: root._headerColors.backgroundColor

    // Square off the bottom corners of the (otherwise fully rounded) title
    // bar so it doesn't show a rounded seam against the real PaneHeader
    // below it.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.radius
        color: parent.color
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: StyleKit.Units.smallSpacing
        anchors.rightMargin: StyleKit.Units.smallSpacing
        spacing: StyleKit.Units.smallSpacing

        Origami.Label {
            text: root.title
            colorSet: StyleKit.Theme.header
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Row {
            id: buttonsRow
            spacing: StyleKit.Units.smallSpacing

            Origami.IconButton {
                enabled: !root.maximized
                iconName: "window-minimize-symbolic"
                onClicked: root.windowItem.toggleMinimize()
            }

            Origami.IconButton {
                enabled: !root.minimized
                iconName: root.maximized ? "window-restore-symbolic" : "window-maximize-symbolic"
                onClicked: root.windowItem.toggleMaximize()
            }

            Origami.IconButton {
                visible: root.closable
                iconName: "window-close-symbolic"
                onClicked: root.windowItem.close()
            }
        }
    }

    // Title-bar drag, repositioning windowItem directly. Maps into
    // windowItem.parent (the host, which never moves) rather than
    // windowItem itself (what's moving) -- same stable-coordinate-frame
    // requirement FloatingWindow.qml's own resize handles have, see their
    // own comment. Disabled while maximized: geometry is pinned to the
    // host in that state, so there's nothing to drag until restored.
    //
    // rightMargin carves out buttonsRow's own hit area, exactly its
    // measured width plus the two gaps around it (Label-to-buttonsRow
    // spacing, buttonsRow-to-edge margin -- both StyleKit.Units.
    // smallSpacing, set above) -- this MouseArea is a sibling declared
    // after the RowLayout, so without the carve-out it would sit on top
    // of the buttons and eat every press before their own internal
    // MouseAreas ever saw it.
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: buttonsRow.width + StyleKit.Units.smallSpacing * 2
        enabled: !root.maximized

        property point _start
        property point _origin

        onPressed: mouse => {
            root.windowItem.bringToFront();
            _start = mapToItem(root.windowItem.parent, mouse.x, mouse.y);
            _origin = Qt.point(root.windowItem.x, root.windowItem.y);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            var p = mapToItem(root.windowItem.parent, mouse.x, mouse.y);
            root.windowItem.x = _origin.x + (p.x - _start.x);
            root.windowItem.y = _origin.y + (p.y - _start.y);
        }
    }
}
