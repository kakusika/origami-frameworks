import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

QQC2.ToolButton {
    id: root
    property string iconName: ""
    property int iconSize: StyleKit.Units.iconSizes.small
    property int colorSet: StyleKit.Theme.header
    readonly property var colors: StyleKit.Theme.paletteFor(root.colorSet)

    implicitWidth: root.iconSize + StyleKit.Units.largeSpacing
    implicitHeight: root.iconSize + StyleKit.Units.largeSpacing

    contentItem: Origami.Icon {
        anchors.centerIn: parent
        color: root.colors.textColor
        source: root.iconName
        width: root.iconSize
        height: root.iconSize
    }
}
