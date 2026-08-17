import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Renders the tab strip for a "tabs" node (see PaneView.qml). Only ever
// shown for an actual "tabs" node: a standalone "pane" node is never
// wrapped in a group of one, so there's nothing for this component to
// draw for it (PaneLeaf.qml just skips straight to the pane's own
// content in that case).
//
// A "tabs" node only exists once the user has explicitly combined two
// panes (drag-and-drop), so there's no "single-tab" state to hide here
// the way there used to be when every leaf carried a tabs array
// regardless of count.
Item {
    id: root
    property var node
    property var controller
    property int leafId: -1
    property int currentIndex: 0

    signal tabClicked(int index)
    signal tabCloseRequested(int tabId)

    visible: !!(root.node && root.node.type === "tabs")
    height: StyleKit.Units.gridUnit * 1.6
    implicitHeight: height

    Origami.PaneTabBar {
        anchors.fill: parent
        node: root.node
        leafId: root.leafId
        currentIndex: root.currentIndex
        controller: root.controller
        onTabClicked: index => root.tabClicked(index)
        onTabCloseRequested: tabId => root.tabCloseRequested(tabId)
    }
}
