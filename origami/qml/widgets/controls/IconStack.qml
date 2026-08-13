import QtQuick
import la.cettila.Origami 1.0

// Composite icon for a tab that stands in for a whole pane group (see
// PaneDrawer.qml's _tabIcons()/PaneTabHeader.qml's iconNames): member
// icons laid out full-size in a single line along `orientation`, growing
// the tab itself rather than shrinking every icon to fit inside one
// icon's usual footprint.
Item {
    id: root

    property var iconNames: []
    property color color: "black"

    property string orientation: "horizontal"

    readonly property bool _vertical: root.orientation === "vertical"
    readonly property int _maxCells: 4
    readonly property real _cellSize: Units.iconSizes.small
    readonly property real _cellSpacing: 1

    readonly property var _cells: {
        var names = root.iconNames || [];
        if (names.length <= root._maxCells)
            return names;
        var shown = names.slice(0, root._maxCells - 1);
        shown.push({
            overflow: names.length - (root._maxCells - 1)
        });
        return shown;
    }

    readonly property real _lineLength: root._cells.length * root._cellSize + Math.max(0, root._cells.length - 1) * root._cellSpacing

    width: root._vertical ? root._cellSize : root._lineLength
    height: root._vertical ? root._lineLength : root._cellSize

    Grid {
        anchors.fill: parent
        columns: root._vertical ? 1 : root._cells.length
        columnSpacing: root._cellSpacing
        rowSpacing: root._cellSpacing

        Repeater {
            model: root._cells

            delegate: Item {
                id: cell
                required property var modelData

                readonly property bool isIcon: typeof cell.modelData === "string"

                width: root._cellSize
                height: root._cellSize

                Icon {
                    anchors.fill: parent
                    visible: cell.isIcon
                    color: root.color
                    source: cell.isIcon ? cell.modelData : ""
                    sourceSize.width: width
                    sourceSize.height: height
                }

                Text {
                    anchors.centerIn: parent
                    visible: !cell.isIcon
                    text: cell.isIcon ? "" : ("+" + cell.modelData.overflow)
                    color: root.color
                    font.pixelSize: cell.height * 0.75
                }
            }
        }
    }
}
