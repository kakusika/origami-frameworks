import QtQuick

// Generic 6-dot drag-grip glyph (a 2x3 or 3x2 grid of small dots) -- a visual
// "grab here to drag" affordance, purely presentational (no MouseArea/
// Drag of its own; callers own the actual drag mechanics, this is just
// what the handle looks like). Custom-drawn dots rather than an icon
// name, so it always renders regardless of the active icon theme (same
// reasoning as PaneSplit.qml's plain Rectangle-based handle). Extracted
// from PaneTabHeader.qml's own `compact` mode glyph -- see that file's
// class comment for its current use (a pane's own drag-to-move handle,
// pinned to its header's top-left corner).
Item {
    id: root

    // Dot color -- callers pass their own theme color; kept context-free
    // (no Theme lookup of its own) so this stays usable anywhere.
    property color color: "black"
    property real dotOpacity: 0.6
    property real dotSize: 2.5
    property real dotSpacing: 1.5
    // Orientation: false = vertical (2 cols x 3 rows), true = horizontal (3 cols x 2 rows)
    property bool horizontal: false

    width: implicitWidth
    height: implicitHeight
    implicitWidth: root.horizontal ? (3 * root.dotSize + 2 * root.dotSpacing) : (2 * root.dotSize + 1 * root.dotSpacing)
    implicitHeight: root.horizontal ? (2 * root.dotSize + 1 * root.dotSpacing) : (3 * root.dotSize + 2 * root.dotSpacing)

    Grid {
        anchors.centerIn: parent
        columns: root.horizontal ? 3 : 2
        rowSpacing: root.dotSpacing
        columnSpacing: root.dotSpacing

        Repeater {
            model: 6

            delegate: Rectangle {
                width: root.dotSize
                height: root.dotSize
                radius: root.dotSize / 2
                color: root.color
                opacity: root.dotOpacity
            }
        }
    }
}
