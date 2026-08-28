import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// A Blender UIList-style container. Combines a ListView with a side action column
// (+, -, Up, Down buttons) for managing editable lists.
Item {
    id: root

    property alias model: listView.model
    property alias delegate: listView.delegate
    property alias currentIndex: listView.currentIndex

    signal addRequested
    signal removeRequested(int index)
    signal moveUpRequested(int index)
    signal moveDownRequested(int index)

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    implicitWidth: StyleKit.Units.gridUnit * 16
    implicitHeight: StyleKit.Units.gridUnit * 12

    RowLayout {
        anchors.fill: parent
        spacing: StyleKit.Units.smallSpacing

        // Main ListView area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: StyleKit.Units.cornerRadius
            color: root.colors.backgroundColor
            border.width: StyleKit.Units.borderWidth
            border.color: StyleKit.Theme.opaqueBlend(root.colors.textColor, root.colors.backgroundColor, 0.25)
            clip: true

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: StyleKit.Units.smallSpacing
                spacing: StyleKit.Units.smallSpacing / 2
                boundsBehavior: Flickable.StopAtBounds

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }
        }

        // Side action button column (+, -, Up, Down)
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: StyleKit.Units.smallSpacing / 2

            Origami.IconButton {
                iconName: "list-add-symbolic"
                QQC2.ToolTip.text: "Add"
                QQC2.ToolTip.visible: hovered
                onClicked: root.addRequested()
            }

            Origami.IconButton {
                iconName: "list-remove-symbolic"
                enabled: listView.currentIndex >= 0
                QQC2.ToolTip.text: "Remove"
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (listView.currentIndex >= 0)
                        root.removeRequested(listView.currentIndex);
                }
            }

            Origami.Separator {
                Layout.fillWidth: true
            }

            Origami.IconButton {
                iconName: "go-up-symbolic"
                enabled: listView.currentIndex > 0
                QQC2.ToolTip.text: "Move Up"
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (listView.currentIndex > 0)
                        root.moveUpRequested(listView.currentIndex);
                }
            }

            Origami.IconButton {
                iconName: "go-down-symbolic"
                enabled: listView.currentIndex >= 0 && listView.currentIndex < (listView.count - 1)
                QQC2.ToolTip.text: "Move Down"
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (listView.currentIndex >= 0 && listView.currentIndex < (listView.count - 1))
                        root.moveDownRequested(listView.currentIndex);
                }
            }
        }
    }
}
