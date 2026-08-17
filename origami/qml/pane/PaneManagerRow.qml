import QtQuick
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// One row of PaneManager.qml's tree view, recursively instantiating itself
// for `node.children` (tabs/split/drawer all share the `{node}`/`{size,
// node}` wrapper shape -- see PaneView.qml's own class comment). Every
// action here calls a real, already-existing PaneView controller function;
// nothing new is invented on the tree-mutation side.
Item {
    id: root

    property var node: null
    property int depth: 0
    property var controller: null
    // The nearest ancestor pane/tabs node's own id -- what a drag/drop
    // operation on this row (or a pane nested inside it) needs as
    // `leafId`. A standalone pane or tabs node is its own enclosing leaf;
    // a pane nested inside a tabs group uses that group's id instead
    // (exactly the leafId/tabId split PaneTabBar.qml's own tab headers
    // already use).
    property int enclosingLeafId: -1

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // `width` is deliberately NOT self-computed from content (no
    // `implicitWidth: column.implicitWidth` here) -- every row at every
    // depth shares the same externally-supplied width (indentation comes
    // from rowRect's own leftMargin below, not from shrinking the row),
    // and `rowRect`/`column` below both bind their width back to
    // `root.width`. Self-computing it (as an earlier version of this file
    // did) created a genuine binding loop: root.implicitWidth <-
    // column.implicitWidth <- rowRect.width <- column.width <- root.width
    // <- root.implicitWidth -- QML resolves loops like this to 0, which
    // collapsed the entire tree view to nothing rendered. See
    // PaneManager.qml's own top-level PaneManagerRow (sets `width:
    // content.width` explicitly) and this file's Loader-based recursion
    // below (propagates the same width down via Qt.binding()) for how
    // `width` actually gets in from outside.
    implicitHeight: column.implicitHeight
    // Unlike Column/Row (which auto-follow their own implicit size), a
    // plain Item's `height` does NOT default to `implicitHeight` -- it
    // stays 0 unless bound explicitly. Without this, `root` (used as a
    // Column child both here recursively via Loader, and at the top level
    // by PaneManager.qml) reports zero height regardless of its real
    // content, so the whole tree view collapses to nothing visible even
    // though `column` itself lays out fine internally.
    height: implicitHeight

    readonly property bool _isPane: !!root.node && root.node.type === "pane"
    readonly property bool _isTabs: !!root.node && root.node.type === "tabs"
    readonly property bool _isDrawer: !!root.node && root.node.type === "drawer"
    readonly property bool _isSplit: !!root.node && root.node.type === "split"
    // Only standalone panes and tabs groups correspond to a real rendered
    // PaneLeaf/leafId -- split/drawer nodes aren't valid requestDrop()
    // targets themselves (see PaneDropOverlay.qml's own `leafId` contract).
    readonly property bool _isLeaf: root._isPane || root._isTabs

    readonly property string _label: {
        if (!root.node)
            return "";
        if (root._isPane)
            return root.node.title || "";
        if (root._isTabs)
            return "タブ (" + root.node.children.length + ")";
        if (root._isDrawer)
            return "ドロワー (" + root.node.children.length + "、" + (root.node.expanded ? "開" : "閉") + ")";
        if (root._isSplit)
            return "分割 (" + (root.node.orientation === "horizontal" ? "横" : "縦") + ")";
        return "";
    }

    readonly property string _iconName: {
        if (!root.node)
            return "";
        if (root._isPane)
            return (root.controller && root.controller.iconRegistry) ? (root.controller.iconRegistry[root.node.viewType] || "") : "";
        if (root._isTabs)
            return "tab-duplicate-symbolic";
        if (root._isDrawer)
            return "sidebar-expand-symbolic";
        if (root._isSplit)
            return root.node.orientation === "horizontal" ? "view-split-left-right" : "view-split-top-bottom";
        return "";
    }

    // Highlights the leaf the user last clicked into (see PaneView.qml's
    // activeLeafId doc comment) -- only meaningful for pane/tabs rows,
    // which are the only ones that can themselves BE a leaf.
    readonly property bool _active: root._isLeaf && !!root.controller && root.controller.activeLeafId === root.node.id

    readonly property bool _hasChildren: !!root.node && !!root.node.children && root.node.children.length > 0
    // Purely a browsing convenience local to this tree view -- distinct
    // from the actual pane tree's own `drawer.expanded` field (that one
    // controls the *real* drawer rail's collapsed state; this one only
    // hides/shows this row's children here). Defaults open so the tree
    // reads as a tree immediately rather than needing every level clicked
    // open first.
    property bool _uiExpanded: true

    Component {
        id: paneWindowComponent
        Origami.PaneWindow {}
    }

    // Mirrors PaneHeader.qml's _openActiveInNewWindow/_moveActiveToNewWindow
    // exactly, just reading `node`/`enclosingLeafId` instead of
    // `_activeTab`/`root.node.id` -- see that file's own comments for the
    // detailed reasoning (parenting to `controller` not `root`, why the
    // window has to be created before detachPane() runs, etc.).
    function _openInNewWindow() {
        if (!root.node || !root.controller)
            return;
        var component = root.controller.componentRegistry ? root.controller.componentRegistry[root.node.viewType] : null;
        if (!component)
            return;
        paneWindowComponent.createObject(root.controller, {
            paneComponent: component,
            title: root.node.title,
            paneViewType: root.node.viewType
        });
    }

    function _moveToNewWindow() {
        if (!root.node || !root.controller)
            return;
        var item = root.controller.materialize(root.node);
        if (!item)
            return;
        var title = root.node.title;
        var viewType = root.node.viewType;
        var areaId = root.enclosingLeafId;
        var paneId = root.node.id;
        paneWindowComponent.createObject(root.controller, {
            hostedItem: item,
            title: title,
            paneViewType: viewType
        });
        root.controller.detachPane(areaId, paneId);
    }

    readonly property var _menuItems: {
        if (!root.node || !root.controller)
            return [];
        if (root._isPane)
            return [
                {
                    text: "アクティブにする",
                    onTriggered: function () {
                        root.controller.setActivePane(root.enclosingLeafId);
                    }
                },
                {
                    text: "別ウィンドウで開く",
                    onTriggered: function () {
                        root._openInNewWindow();
                    }
                },
                {
                    text: "別ウィンドウに移動",
                    onTriggered: function () {
                        root._moveToNewWindow();
                    }
                },
                {
                    text: "閉じる",
                    onTriggered: function () {
                        root.controller.closeTab(root.enclosingLeafId, root.node.id);
                    }
                }
            ];
        if (root._isTabs)
            return [
                {
                    text: "全タブを閉じる",
                    onTriggered: function () {
                        root.controller.closeAllTabs(root.node.id);
                    }
                },
                {
                    text: "ドロワーに変換",
                    onTriggered: function () {
                        root.controller.setGroupType(root.node.id, "drawer");
                    }
                },
                {
                    text: "グループを閉じる",
                    onTriggered: function () {
                        root.controller.closeGroup(root.node.id);
                    }
                }
            ];
        if (root._isDrawer)
            return [
                {
                    text: root.node.expanded ? "折りたたむ" : "展開する",
                    onTriggered: function () {
                        root.controller.setDrawerExpanded(root.node.id, !root.node.expanded);
                    }
                },
                {
                    text: root.node.orientation === "horizontal" ? "縦向きにする" : "横向きにする",
                    onTriggered: function () {
                        root.controller.setDrawerOrientation(root.node.id, root.node.orientation === "horizontal" ? "vertical" : "horizontal");
                    }
                },
                {
                    text: "タブに変換",
                    enabled: root.controller.canConvertDrawerToTabs(root.node.id),
                    onTriggered: function () {
                        root.controller.setGroupType(root.node.id, "tabs");
                    }
                },
                {
                    text: "グループを閉じる",
                    onTriggered: function () {
                        root.controller.closeGroup(root.node.id);
                    }
                }
            ];
        if (root._isSplit)
            return [
                {
                    text: "グループを閉じる",
                    onTriggered: function () {
                        root.controller.closeGroup(root.node.id);
                    }
                }
            ];
        return [];
    }

    Column {
        id: column
        width: root.width
        spacing: 0

        Rectangle {
            id: rowRect
            width: column.width
            height: root._isLeaf ? StyleKit.Units.gridUnit * 1.8 : StyleKit.Units.gridUnit * 1.4
            radius: StyleKit.Units.cornerRadius
            color: root._active ? Qt.rgba(root.colors.highlightColor.r, root.colors.highlightColor.g, root.colors.highlightColor.b, 0.15) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.depth * StyleKit.Units.gridUnit + StyleKit.Units.smallSpacing
                anchors.rightMargin: StyleKit.Units.smallSpacing
                spacing: StyleKit.Units.smallSpacing

                // Expand/collapse chevron -- reserved (but blank/inert) on
                // every row, not just group rows with children, so icons/
                // labels across sibling rows still line up into a
                // consistent column instead of jumping left/right
                // depending on whether that particular row happens to be
                // expandable -- this, plus the per-depth leftMargin above,
                // is what actually makes this read as a tree rather than
                // a flat list.
                Item {
                    Layout.preferredWidth: StyleKit.Units.iconSizes.small
                    Layout.preferredHeight: StyleKit.Units.iconSizes.small

                    Origami.Icon {
                        anchors.fill: parent
                        visible: root._hasChildren
                        source: root._uiExpanded ? "arrow-down" : "arrow-right"
                        color: root.colors.textColor
                    }

                    TapHandler {
                        enabled: root._hasChildren
                        onTapped: root._uiExpanded = !root._uiExpanded
                    }
                }

                // Pane rows: a full (non-compact) PaneTabHeader doubles as
                // both the drag handle AND the icon+title display -- a
                // much bigger, more discoverable drag target than a bare
                // compact grip dot would be (this is exactly how
                // PaneTabBar.qml's own real tab strip renders each tab,
                // just reused here as a row in this tree view instead).
                Origami.PaneTabHeader {
                    Layout.fillWidth: true
                    Layout.preferredHeight: rowRect.height - 4
                    visible: root._isPane
                    compact: false
                    tabId: root.node ? root.node.id : -1
                    leafId: root.enclosingLeafId
                    controller: root.controller
                    title: (root.node && root.node.title) || ""
                    iconName: root._iconName
                    active: root._active
                }

                // Group rows (tabs/split/drawer): plain icon+label, no
                // drag handle -- see this file's own notes on why
                // dragging a whole group isn't supported.
                Origami.Icon {
                    visible: !root._isPane && root._iconName !== ""
                    source: root._iconName
                    width: StyleKit.Units.iconSizes.small
                    height: StyleKit.Units.iconSizes.small
                    color: root.colors.textColor
                }

                Origami.Label {
                    visible: !root._isPane
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root._label
                }

                Origami.HamburgerButton {
                    Layout.preferredHeight: rowRect.height - 4
                    menuItems: root._menuItems
                }
            }

            // Drop target -- standalone-pane and tabs rows only (both
            // correspond to a real leafId; split/drawer nodes don't, see
            // `_isLeaf` above).
            Origami.PaneDropOverlay {
                anchors.fill: parent
                visible: root._isLeaf
                leafId: root.node ? root.node.id : -1
                controller: root.controller
            }
        }

        Repeater {
            model: (root.node && root.node.children) ? root.node.children : []

            // A .qml file can't directly instantiate its own type within
            // its own body (QML rejects it at load time: "Type
            // PaneManagerRow is instantiated recursively") -- Loader with
            // a resolved file URL sidesteps this by deferring type
            // resolution to a runtime file load instead of a static
            // compile-time type reference. Properties are wired via
            // Qt.binding() in onLoaded (rather than plain assignment) so
            // they keep tracking root's own properties/tree changes, not
            // just their value at load time.
            delegate: Loader {
                id: childLoader
                required property var modelData

                source: Qt.resolvedUrl("PaneManagerRow.qml")
                // Collapsed via the chevron above -- Column (this Loader's
                // parent) excludes invisible children from its own layout/
                // spacing, so this correctly shrinks the whole subtree to
                // nothing without unloading (and losing) it.
                visible: root._uiExpanded

                onLoaded: {
                    item.node = Qt.binding(function () {
                        return childLoader.modelData.node;
                    });
                    item.depth = root.depth + 1;
                    item.controller = Qt.binding(function () {
                        return root.controller;
                    });
                    item.enclosingLeafId = Qt.binding(function () {
                        return root._isLeaf ? root.node.id : root.enclosingLeafId;
                    });
                    // Every row at every depth shares the same width (see
                    // root's own `width` comment above) -- propagated down
                    // explicitly since child rows can't compute it from
                    // their own content without recreating the same loop.
                    item.width = Qt.binding(function () {
                        return root.width;
                    });
                }
            }
        }
    }
}
