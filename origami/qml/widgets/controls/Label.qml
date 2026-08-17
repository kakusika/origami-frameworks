pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import StyleKit 1.0 as StyleKit

// Themed drop-in for QQC2's Label. Provides semantic `type` variants:
// plain | secondary | disabled | positive | negative | neutral.
QQC2.Label {
    id: control

    // plain | secondary | disabled | positive | negative | neutral
    property string type: "plain"

    // Which Theme.paletteFor() color set this label's default text color
    // is drawn from. Defaults to `view`.
    property int colorSet: StyleKit.Theme.view

    readonly property var _colors: StyleKit.Theme.paletteFor(control.colorSet)

    readonly property var _semanticColors: ({
            positive: control._colors.positiveTextColor,
            negative: control._colors.negativeTextColor,
            neutral: control._colors.neutralTextColor
        })

    readonly property var _semanticOpacities: ({
            secondary: 0.7,
            disabled: 0.5
        })

    color: control._semanticColors[control.type] ?? control._colors.textColor
    opacity: control._semanticOpacities[control.type] ?? 1.0
}
