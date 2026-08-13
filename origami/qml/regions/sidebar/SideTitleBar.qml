import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Vertical, icon-only bar meant to replace a traditional horizontal menu
// bar (File/Edit/View...). Hovering anywhere over the bar (not necessarily
// over one specific icon) reveals every icon's name as a tooltip at once,
// so the whole bar can be scanned without having to hover each icon in
// turn. Clicking an icon opens that category's items in a menu that pops
// out to the side (to the right of the icon), rather than downward like a
// regular menu bar.
//
// Usage:
//
//   SideTitleBar {
//       anchors.top: parent.top
//       anchors.bottom: parent.bottom
//       anchors.left: parent.left
//       menus: [
//           { text: "ファイル", icon: "document-new", items: ["新規作成", "開く", "保存"] },
//           { text: "編集", icon: "edit-rename", items: ["元に戻す", "やり直し"] }
//       ]
//   }
Rectangle {
    id: root

    // Each entry: { text: string, icon: string, items: array<string> }.
    // `items` becomes the popup menu's entries (plain placeholder labels
    // for now; no action is attached to them yet).
    property var menus: []

    // The Menu currently popped open, if any. Lets a hover over a sibling
    // icon seamlessly switch the open menu (typical menu-bar behavior),
    // matching PaneHeader.qml's menu buttons.
    property var _openMenu: null

    implicitWidth: Units.gridUnit * 2.4

    readonly property var colors: Theme.paletteFor(Theme.header)
    readonly property var tooltipColors: Theme.paletteFor(Theme.tooltip)
    color: root.colors.backgroundColor

    // Tracks the mouse being anywhere over the bar, not just over one
    // particular icon, so all icons' tooltips can be driven from a single
    // shared state below instead of each button's own hover.
    HoverHandler {
        id: barHover
    }

    // Separator against whatever sits to the right (sidebar or main content).
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
    }

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Units.smallSpacing
        spacing: Units.smallSpacing

        Repeater {
            model: root.menus

            delegate: HeaderMenuButton {
                id: menuButton

                // Captured once so the nested Repeater below (which has its
                // own `modelData`) can still reach this entry's fields.
                readonly property var entry: modelData

                width: parent.width
                height: width
                iconName: menuButton.entry.icon
                iconSize: Units.iconSizes.medium
                menuItems: menuButton.entry.items || []
                // Pops out to the side (to the right of the icon) rather
                // than downward like a regular menu bar.
                popupX: menuButton.width
                popupY: 0

                onOpened: root._openMenu = menuButton
                onClosed: if (root._openMenu === menuButton)
                    root._openMenu = null

                // Same seamless hover-to-switch as PaneHeader.qml: only
                // takes over if some other menu in this bar is already
                // open; a first hover with nothing open still requires a
                // click.
                onHoveredChanged: {
                    if (hovered && root._openMenu && root._openMenu !== menuButton) {
                        root._openMenu.requestClose();
                        menuButton.requestOpen();
                    }
                }

                // A plain QQC2.ToolTip can't be used here: the desktop
                // (Breeze) style hardcodes its ToolTip.visible to the
                // button's own `hovered`, ignoring any externally bound
                // value, so a shared bar-wide hover can never drive it.
                // This label is reparented to `root` (SideTitleBar's own
                // background Rectangle) rather than left as a child of
                // `menuButton`, because ToolButton clips its children to its
                // own bounds and the label needs to extend past the
                // button's right edge. `root` doesn't clip, and (unlike the
                // window's Overlay item) is always present, so there's no
                // "not resolved yet" null-parent window to fall into.
                Rectangle {
                    id: label

                    parent: root
                    visible: barHover.hovered
                    z: 1000

                    radius: Units.cornerRadius
                    color: root.tooltipColors.backgroundColor
                    border.width: Units.borderWidth
                    border.color: Qt.rgba(root.tooltipColors.textColor.r, root.tooltipColors.textColor.g, root.tooltipColors.textColor.b, 0.3)

                    implicitWidth: labelText.implicitWidth + Units.largeSpacing * 2
                    implicitHeight: labelText.implicitHeight + Units.smallSpacing * 2
                    // Plain Rectangle-derived items, unlike Control, don't
                    // auto-bind width/height to implicitWidth/implicitHeight,
                    // so without this the label stays zero-sized and never
                    // renders even while `visible` is true.
                    width: implicitWidth
                    height: implicitHeight

                    // Plain property reads instead of menuButton.mapToItem():
                    // QtQuick anchors only resolve correctly between an item
                    // and its parent or siblings, and label (parented to
                    // root) is neither to menuButton (parented to Column),
                    // so cross-hierarchy anchoring silently failed (x/y
                    // stuck at 0). mapToItem() doesn't have that
                    // restriction, but its result isn't tracked by QML's
                    // automatic dependency system, so it never updated once
                    // Column laid the buttons out. Reading menuButton's and
                    // its parent Column's x/y/width directly is a plain
                    // property access, which QML does track reactively.
                    readonly property real buttonRight: menuButton.parent.x + menuButton.x + menuButton.width
                    readonly property real buttonTop: menuButton.parent.y + menuButton.y
                    x: buttonRight + Units.smallSpacing
                    y: buttonTop + (menuButton.height - implicitHeight) / 2

                    Label {
                        id: labelText
                        anchors.centerIn: parent
                        colorSet: Theme.tooltip
                        text: menuButton.entry.text
                    }
                }
            }
        }
    }
}
