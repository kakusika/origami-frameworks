import QtQuick
import la.cettila.Origami 1.0 as Origami

// Shared "seamless hover switch" state for a group of menu-opening
// buttons: hovering a sibling button while another's menu is already open
// swaps the open menu without requiring a fresh click first -- a first
// hover with nothing open still requires a click, exactly matching a
// classic File/Edit menu bar. Extracted out of HeaderMenuGroup.qml (which
// used to keep this state to itself, an internal `_openMenu` var
// coordinating only its own Repeater-built buttons) into its own type so
// a caller with more than one *kind* of menu-opening control in the same
// row -- e.g. PaneHeader.qml's view-type switcher (DropdownButton) and
// paneHeaderModeSwitch items alongside its HeaderMenuGroup -- can share
// one instance across all of them, not just within a single
// HeaderMenuGroup's own buttons.
//
// Works with any button exposing the shape HeaderMenuButton.qml/
// DropdownButton.qml/HamburgerButton.qml all already share: `opened`/
// `closed` signals, a `hovered` property, and requestOpen()/
// requestClose() functions.
QtObject {
    id: root

    // The button currently popped open, if any.
    property var openButton: null

    // Call from a button's onOpened.
    function noteOpened(button) {
        root.openButton = button;
    }

    // Call from a button's onClosed.
    function noteClosed(button) {
        if (root.openButton === button)
            root.openButton = null;
    }

    // Call from a button's onHoveredChanged once `hovered` is true. Swaps
    // the open menu to `button` if some other sibling is currently open;
    // a no-op otherwise.
    function noteHovered(button) {
        if (root.openButton && root.openButton !== button) {
            root.openButton.requestClose();
            button.requestOpen();
        }
    }
}
