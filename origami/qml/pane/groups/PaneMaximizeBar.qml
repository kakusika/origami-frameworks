import QtQuick
import la.cettila.Origami 1.0

// Shown by PaneLeaf.qml instead of PaneTabs when this leaf is the one
// currently maximized (see PaneView.qml's maximizedLeafId) -- Blender's
// "Toggle Maximize Area": this leaf temporarily fills the whole PaneView
// in place of the split/drawer tree it actually lives in, and the only
// thing this bar does is get back out of that. Same height as
// PaneTabs.qml's own tab strip so a leaf's top chrome doesn't jump when
// entering/leaving maximize.
Item {
    id: root
    property var controller
    property int leafId: -1

    height: Units.gridUnit * 1.6
    implicitHeight: height

    HeaderBar {
        id: bar
        anchors.fill: parent

        start: [
            IconButton {
                height: bar.contentHeight
                iconName: "go-previous"
                onClicked: {
                    if (root.controller)
                        root.controller.toggleMaximize(root.leafId);
                }
            }
        ]
    }
}
