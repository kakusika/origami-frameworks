import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

// Pane structure visualizer + drag-and-drop editor + open-windows list.
// Host-agnostic like SettingsPage.qml (cettila-view-settings) -- no title,
// sizing only via implicitWidth/implicitHeight, no assumption about
// whether it's embedded in a regular pane or a standalone PaneWindow.
// Registered as a regular pane type itself (viewType "pane-manager", see
// cettila's main.qml _tabSpecs) -- it can show up inside the very tree it's
// visualizing, same as any other view.
Item {
    id: root

    implicitWidth: Units.gridUnit * 28
    implicitHeight: Units.gridUnit * 24

    readonly property var colors: Theme.paletteFor(Theme.view)

    QQC2.ScrollView {
        id: scroll
        anchors.fill: parent

        // Same width-binding shape SettingsPage.qml's own category
        // ScrollViews use -- binding this Column's width back to
        // `parent.width` (ScrollView's auto-Flickable content item) would
        // create a binding loop against that Flickable's own contentWidth
        // (derived from this Column's implicitWidth), collapsing to 0.
        Column {
            id: content
            x: Units.largeSpacing
            y: Units.largeSpacing
            width: scroll.width - Units.largeSpacing * 2
            spacing: Units.largeSpacing

            Label {
                text: "ペイン構造"
                font.bold: true
            }

            Label {
                visible: !PaneContext.controller || !PaneContext.controller.tree
                type: "secondary"
                text: "ペインがありません。"
            }

            PaneManagerRow {
                visible: !!PaneContext.controller && !!PaneContext.controller.tree
                width: content.width
                node: PaneContext.controller ? PaneContext.controller.tree : null
                depth: 0
                controller: PaneContext.controller
                enclosingLeafId: node ? node.id : -1
            }

            Label {
                text: "別ウィンドウで開いているペイン"
                font.bold: true
            }

            Label {
                visible: PaneWindowRegistry.windows.length === 0
                type: "secondary"
                text: "別ウィンドウで開いているペインはありません。"
            }

            Repeater {
                model: PaneWindowRegistry.windows

                delegate: Item {
                    id: windowRow
                    required property var modelData

                    width: content.width
                    implicitHeight: Units.gridUnit * 1.8
                    height: implicitHeight

                    RowLayout {
                        anchors.fill: parent
                        spacing: Units.smallSpacing

                        Icon {
                            visible: source !== ""
                            source: (PaneContext.controller && PaneContext.controller.iconRegistry) ? (PaneContext.controller.iconRegistry[windowRow.modelData.viewType] || "") : ""
                            width: Units.iconSizes.small
                            height: Units.iconSizes.small
                            color: root.colors.textColor
                        }

                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: windowRow.modelData.title
                        }

                        HamburgerButton {
                            Layout.preferredHeight: windowRow.implicitHeight - 4
                            menuItems: [
                                {
                                    text: "アクティブにする",
                                    onTriggered: function () {
                                        windowRow.modelData.window.show();
                                        windowRow.modelData.window.raise();
                                        windowRow.modelData.window.requestActivate();
                                    }
                                },
                                {
                                    text: "閉じる",
                                    onTriggered: function () {
                                        windowRow.modelData.window.close();
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }
    }
}
