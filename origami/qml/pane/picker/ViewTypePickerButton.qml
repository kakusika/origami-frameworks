import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Blender-style view-type picker: a bordered button (visually identical to
// DropdownButton.qml/HamburgerButton.qml, which this replaces at its two
// call sites -- PaneHeader.qml's type-switcher and PaneTabBar.qml's
// new-tab button) that opens a dedicated popup with a pinned search field
// at the top and a category-grouped, filtered list below.
//
// Deliberately its own component rather than a search option bolted onto
// ThemedMenu.qml (see .agents/tasks/pane-menu-search-box.md's two options):
// QQC2.Menu has no robust way to embed a live TextField among its items
// across styles, and ThemedMenu is a widely shared, delicate file (its own
// class comment notes two earlier failed attempts to restructure how it
// composes) not worth risking for a feature only this one menu family
// needs. Modeled instead on PaneDrawer.qml's own overlayPopup -- a plain
// themed Popup positioned relative to the button, not a QQC2.Menu at all.
//
// `categories` takes the same shape as controller.viewTypeCategories
// itself ([{category, items: [{viewType, title, icon, category}]}]) --
// PaneHeader.qml/PaneTabBar.qml now pass that straight through instead of
// each separately re-mapping it into ThemedMenu's {text, items} shape.
//
// Search: typing filters every entry across every category by substring
// match on title/viewType/category (case-insensitive) and collapses the
// grouped view to one flat match list, same as Blender's own editor-type
// switcher -- see _rows below. Clearing the field restores the grouped
// view. Up/Down chevron keys move a highlight through the current match
// list; Enter activates whichever entry is highlighted (defaulting to the
// first match if none has been touched yet), same as a native menu/
// autocomplete would.
QQC2.ToolButton {
    id: root

    // Same knob DropdownButton.qml/HamburgerButton.qml use.
    property string iconName: ""
    property int iconSize: StyleKit.Units.iconSizes.small

    // Down-chevron affordance -- shown for PaneHeader.qml's "this displays
    // a current value" type-switcher (DropdownButton-style), hidden for
    // PaneTabBar.qml's new-tab button (a pure action, HamburgerButton-
    // style) -- same distinction those two components' own class comments
    // draw.
    property bool showChevron: true

    // See this file's class comment for the shape.
    property var categories: []

    // Marks the matching entry (by viewType) with a persistent highlighted
    // background, same as ThemedMenu.qml's own `selected` entry flag --
    // used by PaneHeader.qml's type-switcher to show the pane's current
    // view type; left blank (no match) by PaneTabBar.qml's new-tab button,
    // which has no "current" value.
    property string selectedViewType: ""

    signal viewTypeSelected(string viewType, string title)

    // Where the popup appears relative to this button. Defaults to
    // opening downward, same as DropdownButton.qml/HamburgerButton.qml's
    // own popupX/popupY.
    property real popupX: 0
    property real popupY: root.height

    property int colorSet: StyleKit.Theme.header
    readonly property var colors: StyleKit.Theme.paletteFor(root.colorSet)
    readonly property alias open: popup.visible

    signal opened
    signal closed

    function requestOpen() {
        popup.x = root.popupX;
        popup.y = root.popupY;
        popup.open();
    }
    function requestClose() {
        popup.close();
    }

    // `checked` (not `checkable` -- nothing should auto-toggle it, only
    // this binding drives it) instead of a hand-painted highlight color:
    // the active QQC2 style already knows how to render a checked
    // toggle/tool button distinctly, so this keeps the "popup is open"
    // affordance without this component owning any background paint.
    // Same fix as DropdownButton.qml/HamburgerButton.qml.
    checked: popup.visible

    implicitHeight: StyleKit.Units.gridUnit * 1.6
    implicitWidth: contentRow.implicitWidth + StyleKit.Units.largeSpacing + 4

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 1

            Origami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.iconName !== ""
                color: root.colors.textColor
                source: root.iconName
                width: root.iconSize
                height: root.iconSize
            }

            Origami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showChevron
                source: "chevron-down"
                color: root.colors.textColor
                width: root.iconSize / 2
                height: root.iconSize / 2
                opacity: 0.6
            }
        }
    }

    // Guards against a race ViewTypePickerPopup.qml's detachedWindow: true
    // introduces (see widgets/Popup.qml's own class comment for what that
    // property is): clicking this same button again while the popup is
    // open is meant to close it, but the popup -- a real top-level window
    // while detached -- closes itself first, on losing window activation
    // to whichever window this very click just brought forward, before
    // this button's own onClicked below even runs. Left alone, root.open
    // already reads false by the time onClicked fires, so the plain
    // toggle would instead *reopen* it -- from the user's perspective,
    // clicking the trigger a second time visibly does nothing (closes,
    // then instantly reopens, confirmed live). This is the one button
    // among DropdownButton.qml/HamburgerButton.qml/HeaderMenuButton.qml/
    // this file that still needs this guard -- the other three build on
    // ThemedMenu.qml, which defaults detachedWindow to false (confined to
    // the app window, no such race) and no call site opts it in.
    //
    // Set unconditionally on every close below. Cleared on a *positive*
    // hoveredChanged -- the cursor genuinely, freshly entering this
    // button -- so a stale flag from an unrelated close (Escape, clicking
    // elsewhere, picking an item) can't wrongly swallow some later click,
    // since reaching this button for that later click always requires a
    // fresh hover-enter first. Guarded on `!root.pressed` too: confirmed
    // live (via temporary console.log instrumentation) that re-clicking
    // this exact button without ever moving the cursor away also fires a
    // hoveredChanged(true) *during* that second press -- not a fresh
    // approach at all, just Qt's own hover state settling as a side
    // effect of the press itself -- which without this guard clears the
    // very flag meant to survive that exact click, immediately undoing
    // it. AbstractButton.pressed alone (checked at the popup's onClosed
    // instead) doesn't work here either -- also confirmed live -- because
    // the window-activation change that closes the popup wins before
    // AbstractButton flips `pressed` true in the first place.
    property bool _suppressReopen: false

    onHoveredChanged: {
        if (root.hovered && !root.pressed)
            root._suppressReopen = false;
    }

    onClicked: {
        if (root._suppressReopen) {
            root._suppressReopen = false;
            return;
        }
        root.open ? root.requestClose() : root.requestOpen();
    }

    Origami.ViewTypePickerPopup {
        id: popup
        parent: root
        categories: root.categories
        selectedViewType: root.selectedViewType
        onViewTypeSelected: (viewType, title) => root.viewTypeSelected(viewType, title)
        onOpened: root.opened()
        onClosed: {
            root.closed();
            root._suppressReopen = true;
        }
    }
}
