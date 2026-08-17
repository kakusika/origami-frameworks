import QtQuick
import StyleKit 1.0 as StyleKit

// Thin vertical divider line for separating grouped content laid out in a
// Row -- faint textColor-at-20%-opacity look.
Rectangle {
    id: root

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    implicitWidth: 1
    implicitHeight: StyleKit.Units.gridUnit
    color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
}
