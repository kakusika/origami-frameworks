import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import la.cettila.Origami 1.0

// Theme-reactive replacement for a plain QQC2.Menu.
QQC2.Menu {
    id: root

    property var menuItems: []
    readonly property var colors: Theme.paletteFor(Theme.header)

    property bool _everOpened: false
    onAboutToShow: root._everOpened = true

    cascade: true
    modal: true
    dim: false

    property bool detachedWindow: false
    popupType: root.detachedWindow ? QQC2.Popup.Window : QQC2.Popup.Item

    padding: Units.smallSpacing

    // No background override -- left to the active QQC2 style's own
    // popup-panel chrome.

    contentItem: ListView {
        implicitHeight: contentHeight
        implicitWidth: contentItem.visibleChildren.reduce((maxWidth, child) => Math.max(maxWidth, child.implicitWidth), 0)
        model: root.contentModel
        interactive: Window.window ? contentHeight + root.topPadding + root.bottomPadding > root.height : false
        clip: true

        QQC2.ScrollIndicator.vertical: QQC2.ScrollIndicator {}

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    return;
                const current = root.itemAt(root.currentIndex);
                if (current && current.subMenu && current.subMenu.visible)
                    return;
                root.currentIndex = -1;
            }
        }
    }

    delegate: Component {
        QQC2.MenuItem {
            id: wrapItem

            // No background override -- `highlighted` is a native
            // MenuItem property the active style already renders
            // distinctly on its own.

            contentItem: Row {
                spacing: Units.smallSpacing
                leftPadding: Units.smallSpacing
                rightPadding: Units.smallSpacing

                Text {
                    text: wrapItem.text
                    verticalAlignment: Text.AlignVCenter
                    color: wrapItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                }

                Icon {
                    visible: wrapItem.subMenu !== null
                    color: wrapItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                    source: "arrow-right-symbolic"
                    width: Units.iconSizes.small
                    height: Units.iconSizes.small
                }
            }
        }
    }

    readonly property var _leafEntries: {
        var result = [];
        for (var i = 0; i < root.menuItems.length; i++) {
            var entry = root.menuItems[i];
            if (!(entry && typeof entry === "object" && entry.items)) {
                result.push({
                    originalIndex: i,
                    entry: entry
                });
            }
        }
        return result;
    }

    readonly property var _submenuEntries: {
        var result = [];
        for (var i = 0; i < root.menuItems.length; i++) {
            var entry = root.menuItems[i];
            if (entry && typeof entry === "object" && entry.items) {
                result.push({
                    originalIndex: i,
                    entry: entry
                });
            }
        }
        return result;
    }

    Instantiator {
        active: root._everOpened
        model: root._leafEntries

        delegate: QQC2.MenuItem {
            id: menuItem
            required property var modelData
            readonly property var _entry: menuItem.modelData.entry

            text: (typeof menuItem._entry === "string") ? menuItem._entry : menuItem._entry.text
            readonly property bool _selected: (typeof menuItem._entry === "string") ? false : (menuItem._entry.selected === true)
            enabled: (typeof menuItem._entry === "string") ? true : (menuItem._entry.enabled !== false) && !menuItem._selected

            readonly property string _iconName: (typeof menuItem._entry === "string") ? "" : (menuItem._entry.icon || "")

            // Left as a background override, unlike this file's other two
            // -- `_selected` isn't native `highlighted` state, it's "this
            // entry is the current value" from external data. The
            // idiomatic native equivalent would be `checked`, but that
            // needs `checkable: true` to actually render, and `checkable`
            // makes QQC2 auto-toggle `checked` on click, which would
            // fight this live `_selected` binding (severs it on the
            // first click). Not safe to change without also reworking
            // how selection here interacts with `onTriggered` below.
            background: Rectangle {
                radius: Units.cornerRadius
                color: (menuItem.highlighted || menuItem._selected) ? root.colors.highlightColor : "transparent"
            }

            contentItem: Row {
                spacing: Units.smallSpacing
                leftPadding: Units.smallSpacing
                rightPadding: Units.smallSpacing

                Icon {
                    visible: menuItem._iconName !== ""
                    color: root.colors.textColor
                    source: menuItem._iconName
                    width: Units.iconSizes.small
                    height: Units.iconSizes.small
                }

                Text {
                    text: menuItem.text
                    verticalAlignment: Text.AlignVCenter
                    color: menuItem._selected ? root.colors.highlightedTextColor : (!menuItem.enabled ? Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.4) : (menuItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor))
                }
            }

            onTriggered: {
                if (menuItem._entry && menuItem._entry.onTriggered)
                    menuItem._entry.onTriggered();
            }
        }

        onObjectAdded: (index, object) => root.insertItem(object.modelData.originalIndex, object)
        onObjectRemoved: (index, object) => root.removeItem(object)
    }

    Instantiator {
        active: root._everOpened
        model: root._submenuEntries

        delegate: ThemedSubMenu {
            id: submenu
            required property var modelData

            title: submenu.modelData.entry.text
            menuItems: submenu.modelData.entry.items || []
            detachedWindow: root.detachedWindow
        }

        onObjectAdded: (index, object) => root.insertMenu(object.modelData.originalIndex, object)
        onObjectRemoved: (index, object) => root.removeMenu(object)
    }
}
