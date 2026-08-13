import QtQuick
import la.cettila.Origami 1.0

// Multi-line header: a top start/center/end row (HeaderBarRow.qml, the same
// layout HeaderBar.qml itself uses) followed by zero or more additional
// rows stacked below it. Unlike the top row, extra rows have no
// start/center/end split -- just plain left-to-right placement -- and the
// caller decides exactly what goes in each one; this component never
// redistributes or wraps items across rows itself (no automatic flow
// layout based on available width). Pure layout, no background of its own
// -- same reasoning as HeaderBar.qml's own class comment; PaneHeader.qml
// (today's only caller) draws its own Theme.header background behind it.
//
// Usage:
//
//   MultiRowHeaderBar {
//       start: [ IconButton { iconName: "document-new" } ]
//       end: [ HeaderMenuGroup { menus: [...] } ]
//       extraRows: [
//           Row {
//               spacing: Units.smallSpacing
//               Button { text: "A" }
//               Button { text: "B" }
//           },
//           Row {
//               Button { text: "C" }
//           }
//       ]
//   }
Item {
    id: root

    // Top row's start/center/end slots -- same meaning as HeaderBar.qml.
    property list<QtObject> start
    property list<QtObject> center
    property list<QtObject> end

    // Rows stacked below the top row, top to bottom, in list order. Each
    // entry is a single Item (typically a plain Row) supplied by the
    // caller -- what goes in it, and in what order, is entirely up to the
    // caller; this component just stacks whatever it's given.
    property list<QtObject> extraRows

    // Height every row's own content should size itself to -- same
    // meaning and value as HeaderBar.qml's contentHeight, exposed here so
    // extraRows items can size consistently with the top row.
    readonly property real contentHeight: topRow.contentHeight

    // Forwards the top row's own centerWidth (see HeaderBarRow.qml's class
    // comment) so a caller can work out how much room `start`/`end`
    // actually have before running into `center`.
    readonly property real centerWidth: topRow.centerWidth

    implicitHeight: column.implicitHeight
    height: implicitHeight

    Column {
        id: column
        anchors.fill: parent

        HeaderBarRow {
            id: topRow
            width: column.width
            start: root.start
            center: root.center
            end: root.end
        }

        Column {
            id: extraRowsColumn

            // Horizontal inset via x/width (not leftPadding) -- Column's
            // leftPadding shifts children's starting x but never reduces
            // the width they're told to fill, so a row Item bound to
            // width: parent.width (the documented way for a caller's row
            // to span the available width -- see Explorer.qml's
            // paneHeaderExtraRow) would overflow past the right edge by
            // exactly leftPadding's worth, since it'd still be as wide as
            // the *unindented* column.width while starting leftPadding
            // pixels in. Pre-narrowing width here (and offsetting x to
            // match) means parent.width already *is* the correct,
            // available inner width -- no further arithmetic needed by
            // whatever row Item ends up here.
            readonly property real _inset: root.extraRows.length > 0 ? Units.smallSpacing : 0
            x: extraRowsColumn._inset
            width: column.width - extraRowsColumn._inset * 2
            spacing: Units.smallSpacing
            // Vertical margin around the whole extra-rows block, matching
            // the top row's own inset (HeaderBarRow.contentHeight) -- the
            // top row gets its padding from centering each content item
            // inside a shorter contentHeight, which only applies to
            // HeaderBarRow's own start/center/end slots; extra rows have
            // no such mechanism (their own height is whatever the caller's
            // content needs), so this Column's topPadding/bottomPadding is
            // what actually gives them the equivalent margin.
            //
            // Gated on root.extraRows being non-empty -- a Column's
            // topPadding/bottomPadding add to its implicitHeight even with
            // zero children, so leaving these unconditional left every
            // single-row header (no extraRows at all) with a stray blank
            // gap below its one real row.
            topPadding: root.extraRows.length > 0 ? Units.smallSpacing : 0
            bottomPadding: root.extraRows.length > 0 ? Units.smallSpacing : 0
            data: root.extraRows
        }
    }
}
