import QtQuick
import StyleKit 1.0 as StyleKit

// Pure start/center/end row layout, no background -- the reusable core of
// Bar.qml, factored out so MultiRowBar.qml can stack one of
// these as its top row without drawing a second, redundant background
// underneath it. Not meant to be used directly outside those two --
// Bar.qml for a single-line bar, MultiRowBar.qml for a
// multi-line one.
Item {
    id: root

    property list<QtObject> start
    property list<QtObject> center
    property list<QtObject> end

    // Height content items should size themselves to, rather than
    // `height` directly, so bordered/backgrounded children (a
    // DropdownButton, a highlighted menu button, ...) don't touch this
    // row's own top/bottom edges. The single source of truth for this --
    // Bar.qml and MultiRowBar.qml both forward their own
    // `contentHeight` to this one instead of recomputing the same "-4"
    // themselves.
    readonly property real contentHeight: root.height - 4

    // Forwards the `end` row's own width so a caller can work out how much
    // space is actually left for `start` (e.g. PaneTabBar.qml deciding
    // whether its tabs overflow into this row) -- neither row reserves
    // space for the other, they just anchor from opposite edges and can
    // visually overlap once `start` grows too wide.
    readonly property real endWidth: endRow.width

    // Forwards the `center` row's own width, same reasoning as endWidth
    // above -- centerRow is independently centered (anchors.centerIn:
    // parent below), so it also reserves no space of its own; a caller
    // that wants `start` (or `end`) to stop short of overlapping it needs
    // this to work out where centerRow's own left/right edges actually
    // land (see PaneHeader.qml's _menuGroupAvailableWidth).
    readonly property real centerWidth: centerRow.width

    // No explicit `height:` binding (only implicitHeight) so a parent can
    // freely override sizing (e.g. via anchors.fill) without fighting a
    // conflicting binding on the same property.
    implicitHeight: StyleKit.Units.gridUnit * 1.6

    Row {
        id: startRow
        anchors.left: parent.left
        anchors.leftMargin: StyleKit.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleKit.Units.smallSpacing
        data: root.start
    }

    Row {
        id: centerRow
        anchors.centerIn: parent
        spacing: StyleKit.Units.smallSpacing
        data: root.center
    }

    Row {
        id: endRow
        anchors.right: parent.right
        anchors.rightMargin: StyleKit.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleKit.Units.smallSpacing
        data: root.end
    }
}
