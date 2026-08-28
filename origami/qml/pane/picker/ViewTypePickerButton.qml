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

    // Only ever opens from here -- never closes itself via a toggle. A
    // second click on this same button while the popup is open never
    // reaches this handler at all (ViewTypePickerPopup.qml's own
    // modal: true overlay catches that press first, as a press outside
    // its own content, and closes the popup there); the *third* click
    // then genuinely starts fresh, with nothing left open, and reopens it
    // normally. Same "trigger only opens, the popup's own closePolicy
    // handles closing" shape as every other plain-Popup trigger in this
    // codebase (ToggleGroup.qml's detailsButton, CollapsibleTextField.qml's
    // collapsed-state TapHandler) -- see ViewTypePickerPopup.qml's own
    // closePolicy comment for why this one specifically needs
    // CloseOnPressOutside rather than those others' ...OutsideParent.
    // `requestClose()` stays a real, separately-callable function --
    // PaneHeader.qml's _menuCoordinator calls it directly to close this
    // popup when a sibling menu opens.
    onClicked: {
        if (!root.open)
            root.requestOpen();
    }

    Origami.ViewTypePickerPopup {
        id: popup
        parent: root
        categories: root.categories
        selectedViewType: root.selectedViewType
        onViewTypeSelected: (viewType, title) => root.viewTypeSelected(viewType, title)
        onOpened: root.opened()
        onClosed: root.closed()
    }
}
