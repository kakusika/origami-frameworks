import QtQuick
import la.cettila.Origami 1.0

// Generic, reusable header/toolbar shell: three content slots -- `start`
// (pinned left), `center` (centered in the whole bar), and `end` (pinned
// right). Pure layout, no background/appearance of its own -- every caller
// draws whatever background it wants itself (e.g. PaneHeader.qml's own
// Theme.header Rectangle), so this stays reusable for headers that want no
// visible chrome at all (PaneDrawer.qml's collapse header, PaneTabBar.qml's
// tab strip -- both draw their own tabs/buttons and want nothing extra
// behind them). No menu-specific or pane-specific logic lives here either.
// For a header that needs more than one line, see MultiRowHeaderBar.qml
// instead -- it reuses this same start/center/end layout (HeaderBarRow.qml)
// for its top row, plus caller-specified extra rows below.
//
// Usage:
//
//   HeaderBar {
//       start: [
//           IconButton { iconName: "document-new" }
//       ]
//       end: [
//           HeaderMenuGroup { menus: [...] }
//       ]
//   }
Item {
    id: root

    property list<QtObject> start
    property list<QtObject> center
    property list<QtObject> end

    // Forwards HeaderBarRow's own contentHeight (see its class comment) --
    // every start/center/end item is expected to size itself to this,
    // not just the ones that happen to have a visible border, so the
    // whole bar reads as one consistent vertical inset.
    readonly property real contentHeight: row.contentHeight

    // Forwards HeaderBarRow's own endWidth (see its class comment) so a
    // caller can work out how much room `start` actually has before
    // running into `end`.
    readonly property real endWidth: row.endWidth

    // Forwards HeaderBarRow's own centerWidth (see its class comment) so a
    // caller can work out how much room `start`/`end` actually have before
    // running into `center`.
    readonly property real centerWidth: row.centerWidth

    height: Units.gridUnit * 1.6
    // See PaneTabBar.qml for why implicitHeight (not just height) must be
    // set for a plain Item to get its share of the parent ColumnLayout.
    implicitHeight: height

    HeaderBarRow {
        id: row
        anchors.fill: parent
        start: root.start
        center: root.center
        end: root.end
    }
}
