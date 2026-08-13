import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Pure action-menu button: shows a text label (e.g. PaneHeader.qml's
// "ファイル"/"編集"/"表示") or an icon (e.g. SideTitleBar.qml's vertical
// icon bar, PaneDrawer.qml/PaneTabBar.qml's "convert to tabs/drawer"
// hamburgers), and opens a ThemedMenu built from `menuItems` on click --
// never a "currently selected value" (that's DropdownButton.qml's job, e.g.
// PaneHeader.qml's view-type switcher or SettingsPage.qml's style/font-
// size pickers). Kept as its own component rather than reusing DropdownButton
// for this too, so the two concepts -- "pick one of several actions" vs.
// "pick/display one of several values" -- stay distinct: this button
// never shows a trailing chevron, unlike DropdownButton.
//
// Extracted from PaneHeader.qml's menu-bar Repeater (its own placeholder
// menus, and each view's optional paneHeaderMenus override -- e.g.
// BoardView.qml's "ファイル"/"追加", Explorer.qml's "表示") and
// SideTitleBar.qml's icon bar.
QQC2.ToolButton {
    id: root

    // Content: either a text label or an icon, via the custom
    // `contentItem` below rather than ToolButton's own inherited `icon`
    // group -- named `iconName` (not `icon`) specifically to avoid
    // colliding with that inherited property (same reason
    // IconButton.qml/DropdownButton.qml use `iconName` too). Showing
    // both isn't supported -- callers only ever need one or the other.
    property string iconName: ""
    property int iconSize: Units.iconSizes.medium

    // Each entry is either a plain string (inert placeholder, no action)
    // or {text, onTriggered, enabled} (a real action; enabled defaults to
    // true if omitted).
    property var menuItems: []

    // Where the popup appears relative to this button. Defaults to
    // opening downward (PaneHeader.qml's menu-bar layout);
    // SideTitleBar.qml overrides this to pop out to the side instead.
    property real popupX: 0
    property real popupY: root.height

    // Corner rounding for this button's own highlight/hover background.
    // Left/right rather than full per-corner, since buttons in a menu bar
    // only ever need their outer edge rounded (HeaderMenuGroup.qml rounds
    // the first entry's left side and the last entry's right side, so the
    // group reads as one rounded bar; every button in between stays 0 on
    // both).
    property real leftRadius: 0
    property real rightRadius: 0

    property int colorSet: Theme.header
    readonly property var colors: Theme.paletteFor(root.colorSet)
    readonly property alias open: menu.visible

    signal opened
    signal closed

    function requestOpen() {
        menu.popup(root, root.popupX, root.popupY);
    }
    function requestClose() {
        menu.close();
    }

    implicitHeight: Units.gridUnit * 1.6
    // Explicit rather than relying on Control's automatic
    // implicitContentWidth+padding sizing: the active QQC2 style's own
    // ToolButton implementation can otherwise enforce a wider default/
    // minimum button width than this content actually needs.
    implicitWidth: (root.iconName !== "" ? iconItem.width : labelItem.implicitWidth) + Units.largeSpacing + Units.smallSpacing

    background: Rectangle {
        color: menu.visible ? root.colors.highlightColor : (root.hovered ? root.colors.hoverColor : "transparent")
        topLeftRadius: root.leftRadius
        bottomLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomRightRadius: root.rightRadius
    }

    contentItem: Item {
        Icon {
            id: iconItem
            anchors.centerIn: parent
            visible: root.iconName !== ""
            // Symbolic icons are the only ones IconImage actually
            // recolors (see Icon.qml's own class comment) -- a
            // non-symbolic icon just keeps its own theme-baked colors
            // regardless of this.
            color: menu.visible ? root.colors.highlightedTextColor : root.colors.textColor
            source: root.iconName
            width: root.iconSize
            height: root.iconSize
        }

        Text {
            id: labelItem
            anchors.centerIn: parent
            visible: root.iconName === ""
            text: root.text
            color: menu.visible ? root.colors.highlightedTextColor : root.colors.textColor
        }
    }

    onClicked: root.open ? root.requestClose() : root.requestOpen()

    ThemedMenu {
        id: menu
        menuItems: root.menuItems
        onOpened: root.opened()
        onClosed: root.closed()
    }
}
