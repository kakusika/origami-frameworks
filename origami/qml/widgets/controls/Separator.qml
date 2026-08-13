import QtQuick
import la.cettila.Origami 1.0 as Origami

// Thin vertical divider line for separating grouped content laid out in a
// Row -- faint textColor-at-20%-opacity look.
Rectangle {
    id: root

    readonly property var colors: Origami.Theme.paletteFor(Origami.Theme.header)

    implicitWidth: 1
    implicitHeight: Origami.Units.gridUnit
    color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
}
