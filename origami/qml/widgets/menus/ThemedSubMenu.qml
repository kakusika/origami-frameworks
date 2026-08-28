import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Nestable submenu counterpart to ThemedMenu.qml. Mirrors that file's
// _leafEntries/_submenuEntries split and two-Instantiator structure almost
// verbatim, so a `{text, items}` entry nested *inside* a submenu recurses
// into a further Origami.ThemedSubMenu instead of being flattened into an
// inert leaf -- callers (e.g. cettila-view-node-graph's NodeGraphView.qml,
// building a category tree from a fetched ComfyUI node catalog) can nest
// menus arbitrarily deep, not just the one level ThemedMenu.qml's own
// top-level _submenuEntries handling reaches on its own.
//
// The only real differences from ThemedMenu.qml: modal/dim stay false
// (this menu is already nested inside an open QQC2.Menu tree, so it
// doesn't need to dim the background itself -- the top-level ThemedMenu
// already did), and a nested `{text, items}` entry recurses into
// Origami.ThemedSubMenu (itself) rather than ThemedMenu.qml's own
// recursion target.
QQC2.Menu {
    id: root

    property var menuItems: []
    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    property bool _everOpened: false
    onAboutToShow: root._everOpened = true

    cascade: true
    modal: false
    dim: false

    property bool detachedWindow: false
    popupType: root.detachedWindow ? QQC2.Popup.Window : QQC2.Popup.Item

    padding: StyleKit.Units.smallSpacing

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

    // Default per-item chrome (label + "has a submenu" arrow) for
    // whatever QQC2.Menu ends up putting in contentModel besides the
    // Instantiator-managed items/menus below (kept identical to
    // ThemedMenu.qml's own copy, see that file for why this exists
    // separately from the Instantiator delegates' own contentItem).
    delegate: Component {
        QQC2.MenuItem {
            id: wrapItem

            // No background override -- `highlighted` is a native
            // MenuItem property the active style already renders
            // distinctly on its own.

            contentItem: Row {
                spacing: StyleKit.Units.smallSpacing
                leftPadding: StyleKit.Units.smallSpacing
                rightPadding: StyleKit.Units.smallSpacing

                Text {
                    text: wrapItem.text
                    verticalAlignment: Text.AlignVCenter
                    color: wrapItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                }

                Origami.Icon {
                    visible: wrapItem.subMenu !== null
                    color: wrapItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor
                    source: "arrow-right-symbolic"
                    width: StyleKit.Units.iconSizes.small
                    height: StyleKit.Units.iconSizes.small
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
            // entry is the current value" from external data. See
            // ThemedMenu.qml's identical comment for the full rationale
            // (not safe to change without reworking selection here).
            background: Rectangle {
                radius: StyleKit.Units.cornerRadius
                color: (menuItem.highlighted || menuItem._selected) ? root.colors.highlightColor : "transparent"
            }

            contentItem: Row {
                spacing: StyleKit.Units.smallSpacing
                leftPadding: StyleKit.Units.smallSpacing
                rightPadding: StyleKit.Units.smallSpacing

                Origami.Icon {
                    visible: menuItem._iconName !== ""
                    color: root.colors.textColor
                    source: menuItem._iconName
                    width: StyleKit.Units.iconSizes.small
                    height: StyleKit.Units.iconSizes.small
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

    // Recurses into further Origami.ThemedSubMenu instances -- see this
    // file's class comment for why that's what makes arbitrary-depth
    // nesting possible. Loaded via a URL (`source`, not `sourceComponent`/
    // an inline `Origami.ThemedSubMenu {}`) specifically so this stays a
    // *runtime* recursion: a QML file directly instantiating its own type
    // inline is a static self-reference the QML tooling that processes
    // this module rejects outright ("Type is instantiated recursively",
    // surfacing as this exact submenu failing to load at all). Resolving
    // the next level by URL instead keeps that same-type reference out of
    // this document's static type-dependency graph -- it's only looked up
    // once this Loader actually activates, same as any other dynamically-
    // loaded QML file.
    Instantiator {
        active: root._everOpened
        model: root._submenuEntries

        delegate: Loader {
            id: submenuLoader
            required property var modelData

            asynchronous: false
            source: Qt.resolvedUrl("ThemedSubMenu.qml")

            onLoaded: {
                item.title = submenuLoader.modelData.entry.text;
                item.menuItems = submenuLoader.modelData.entry.items || [];
                item.detachedWindow = root.detachedWindow;
                root.insertMenu(submenuLoader.modelData.originalIndex, item);
            }
        }

        onObjectRemoved: (index, object) => {
            if (object.item)
                root.removeMenu(object.item);
        }
    }
}
