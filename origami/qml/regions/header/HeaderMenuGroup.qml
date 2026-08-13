import QtQuick
import la.cettila.Origami 1.0

// Row of HeaderMenuButton.qml entries sharing "seamless hover switch"
// behavior: hovering a sibling button while another's menu is already open
// swaps the open menu without requiring a fresh click first -- a first
// hover with nothing open still requires a click, exactly matching a
// classic File/Edit menu bar. Extracted from PaneHeader.qml's menu Repeater
// so the same grouped-menu-bar shape can be reused elsewhere (meant for
// HeaderBar.qml's start/center/end slots).
Row {
    id: root

    // Each entry: {text, items}, where items is HeaderMenuButton.menuItems
    // (plain strings for inert placeholders, or {text, onTriggered,
    // enabled} for real actions).
    property var menus: []
    property real buttonHeight: Units.gridUnit * 1.6

    // How much horizontal room the caller can actually give this group
    // before it must stop showing one button per menu. Infinity (never
    // collapse) by default so every existing call site that doesn't set
    // this keeps its previous behavior unchanged. PaneHeader.qml is the
    // one caller that does set it, since it's the one place these can
    // run out of room -- a narrow split/tabbed pane's header has far
    // less width to work with than a top-level window's menu bar would.
    property real availableWidth: Infinity

    // Shared "seamless hover switch" state (see HeaderMenuCoordinator.
    // qml's own class comment) -- lets a hover over a sibling button
    // switch the open menu instead of requiring a fresh click to
    // close-then-reopen. Only meaningful in the uncollapsed
    // (one-button-per-menu) layout below. Defaults to a private,
    // group-local instance so every existing call site that doesn't set
    // this keeps coordinating only among this group's own buttons, same
    // as before; a caller with other menu-opening controls outside this
    // group (e.g. PaneHeader.qml's view-type switcher) can pass in its
    // own shared instance instead to fold this group into that wider
    // hover-switch set.
    property QtObject coordinator: HeaderMenuCoordinator {}

    // Whether buttonsRow (below) would need more width than this group
    // has actually been given. Read off buttonsRow.implicitWidth rather
    // than root.implicitWidth: an item's own implicit-size computation
    // doesn't depend on its `visible` property (only a *parent*
    // positioner's arrangement does), so this stays correct even while
    // buttonsRow itself is hidden by the branch it feeds into.
    readonly property bool _collapsed: buttonsRow.implicitWidth > root.availableWidth

    // No spacing between entries by default: a classic File/Edit menu bar
    // sits its buttons flush against each other (only the hover/open
    // background highlight sets them apart), matching PaneHeader.qml's
    // original layout.

    Row {
        id: buttonsRow
        visible: !root._collapsed

        Repeater {
            model: root.menus

            delegate: HeaderMenuButton {
                id: menuButton
                required property var modelData
                required property int index

                height: root.buttonHeight
                text: menuButton.modelData.text
                menuItems: menuButton.modelData.items || []

                leftRadius: Units.cornerRadius
                rightRadius: Units.cornerRadius
                // leftRadius: menuButton.index === 0 ? Units.cornerRadius : 0
                // rightRadius: menuButton.index === root.menus.length - 1 ? Units.cornerRadius : 0

                onOpened: root.coordinator.noteOpened(menuButton)
                onClosed: root.coordinator.noteClosed(menuButton)
                onHoveredChanged: {
                    if (hovered)
                        root.coordinator.noteHovered(menuButton);
                }
            }
        }
    }

    // Collapsed fallback: every menu nested as its own cascading submenu
    // (same "application-menu-symbolic" icon PaneDrawer.qml/PaneTabBar.qml
    // already use for their own group-level overflow menus), swapped in
    // instead of silently letting buttonsRow overflow past this pane's
    // own edge once there isn't room for one button per menu. root.menus
    // is already exactly the {text, items} shape ThemedMenu.qml
    // recognizes as a submenu entry, so it's passed straight through --
    // no flattening needed.
    HamburgerButton {
        id: collapsedButton
        visible: root._collapsed
        width: root.buttonHeight
        height: root.buttonHeight
        iconName: "application-menu-symbolic"
        menuItems: root.menus
    }
}
