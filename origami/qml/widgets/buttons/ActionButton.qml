pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami

QQC2.Button {
    id: control

    property string tooltip: ""
    property bool destructive: false

    readonly property var _colors: Origami.Theme.paletteFor(Origami.Theme.header)
    readonly property color _textColor: control.destructive ? control._colors.negativeTextColor : control._colors.textColor

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: control.enabled ? 1.0 : 0.4

    implicitHeight: Origami.Units.gridUnit * 1.6
    implicitWidth: labelItem.implicitWidth + Origami.Units.largeSpacing * 2

    contentItem: QQC2.Label {
        id: labelItem
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: control.text
        color: control._textColor
    }

    QQC2.ToolTip.visible: hovered && tooltip.length > 0
    QQC2.ToolTip.text: tooltip

    Accessible.role: Accessible.Button
}
