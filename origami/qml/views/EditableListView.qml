import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

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

    readonly property var colors: Theme.paletteFor(Theme.view)

    implicitWidth: Units.gridUnit * 16
    implicitHeight: Units.gridUnit * 12

    RowLayout {
        anchors.fill: parent
        spacing: Units.smallSpacing

        // Main ListView area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Units.cornerRadius
            color: root.colors.backgroundColor
            border.width: Units.borderWidth
            border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.25)
            clip: true

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: Units.smallSpacing
                spacing: Units.smallSpacing / 2
                boundsBehavior: Flickable.StopAtBounds

                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            }
        }

        // Side action button column (+, -, Up, Down)
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: Units.smallSpacing / 2

            IconButton {
                iconName: "list-add-symbolic"
                QQC2.ToolTip.text: "Add"
                QQC2.ToolTip.visible: hovered
                onClicked: root.addRequested()
            }

            IconButton {
                iconName: "list-remove-symbolic"
                enabled: listView.currentIndex >= 0
                QQC2.ToolTip.text: "Remove"
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (listView.currentIndex >= 0)
                        root.removeRequested(listView.currentIndex);
                }
            }

            Separator {
                Layout.fillWidth: true
            }

            IconButton {
                iconName: "go-up-symbolic"
                enabled: listView.currentIndex > 0
                QQC2.ToolTip.text: "Move Up"
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (listView.currentIndex > 0)
                        root.moveUpRequested(listView.currentIndex);
                }
            }

            IconButton {
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
