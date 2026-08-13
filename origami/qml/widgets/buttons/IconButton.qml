import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

QQC2.ToolButton {
    id: root
    property string iconName: ""
    property int iconSize: Units.iconSizes.small
    property int colorSet: Theme.header
    readonly property var colors: Theme.paletteFor(root.colorSet)

    implicitWidth: root.iconSize + Units.largeSpacing
    implicitHeight: root.iconSize + Units.largeSpacing

    contentItem: Icon {
        anchors.centerIn: parent
        color: root.colors.textColor
        source: root.iconName
        width: root.iconSize
        height: root.iconSize
    }
}
