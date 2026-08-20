import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// 1つのタブヘッダー。ドラッグの起点。
//
// 実装上の注意: ドラッグ対象を「このヘッダー自身」ではなく、
// controller.dragLayer(root基準の最上位オーバーレイ)に住む
// 半透明のdragProxyにしている。ヘッダー自身は元の階層(leaf内の
// タブバー)に留まったまま動かないので、ドロップが不発でも位置が
// おかしくなることがない。dragProxyはDrag.active/keysを持ち、他の
// PaneLeafが持つPaneDropOverlay(DropArea)へ実際にドロップされる。
Rectangle {
    id: root
    property string title: ""
    property int tabId: -1
    property int leafId: -1
    property bool active: false
    property var controller

    // Freedesktop icon name shown before the title (empty = no icon).
    // Looked up by the caller from controller.iconRegistry, same as
    // PaneHeader.qml's own _activeIcon.
    property string iconName: ""

    // Icons for a tab that stands in for a whole nested pane group
    // (PaneDrawer.qml's _tabIcons() -- a rail tab whose child is itself a
    // "tabs"/"drawer" group, not a bare pane) rather than one view: one
    // entry per member pane. Empty for the ordinary single-pane case,
    // where iconName above is used instead. More than one entry renders
    // as a composite IconStack in place of the plain Icon below -- see
    // _composite/_singleIconName.
    property var iconNames: []

    // Which way the tabs in this strip themselves flow -- "horizontal"
    // for the ordinary tab row and PaneDrawer.qml's horizontal rail,
    // "vertical" for its vertical rail. Forwarded to the IconStack below
    // (see its own `orientation` comment) so a composite tab's 2-icon
    // layout lines up with the strip instead of always defaulting to
    // one shape.
    property string iconStackOrientation: "horizontal"

    readonly property bool _composite: root.iconNames.length > 1
    // A lone iconNames entry (a group with exactly one member -- can
    // happen transiently) is shown the same as an ordinary single icon,
    // so iconName doesn't need to be duplicated by every caller.
    readonly property string _singleIconName: root.iconNames.length === 1 ? root.iconNames[0] : root.iconName

    // When true, hides the title text and shrinks the tab down to just
    // its icon -- used by PaneTabBar.qml when the pane is too narrow for
    // every tab to show its full title.
    property bool iconOnly: false

    // Width this tab would take with its title shown, regardless of the
    // current iconOnly value -- used by PaneTabBar.qml to detect whether
    // the full tab row would actually overflow the available space (see
    // its own _iconOnly comment).
    readonly property real _iconAreaWidth: root._composite ? iconStack.width : (root._singleIconName !== "" ? StyleKit.Units.iconSizes.small : 0)
    readonly property real fullWidth: (_iconAreaWidth > 0 ? _iconAreaWidth + StyleKit.Units.smallSpacing : 0) + titleMetrics.implicitWidth + StyleKit.Units.largeSpacing * 2

    // 押してからこのpx数だけ動かすまでは、ただのクリックとして扱い
    // ドラッグを開始しない。
    property real dragThreshold: Qt.styleHints.startDragDistance

    property bool _hovered: false

    // Which edge the active-tab accent line (below) is drawn against --
    // "bottom" for a horizontal tab row (PaneTabBar.qml's default use),
    // "right" for PaneDrawer.qml's vertical rail, where the active tab's
    // content shows to the right of it.
    property string activeEdge: "bottom"

    signal clicked
    signal closeRequested

    // アクティブなタブは中身(View配色)と同じ背景にして地続きに見せ、
    // 非アクティブなタブは親(PaneTabBar、Header配色)に馴染ませる。
    readonly property var colors: StyleKit.Theme.paletteFor(root.active ? StyleKit.Theme.view : StyleKit.Theme.header)

    width: contentRow.implicitWidth + StyleKit.Units.largeSpacing * 2
    readonly property real _iconAreaHeight: root._composite ? iconStack.height : StyleKit.Units.iconSizes.small
    height: Math.max(StyleKit.Units.gridUnit * 1.6, root._iconAreaHeight + (StyleKit.Units.gridUnit * 1.6 - StyleKit.Units.iconSizes.small))

    topLeftRadius: StyleKit.Units.cornerRadius
    topRightRadius: StyleKit.Units.cornerRadius
    bottomLeftRadius: StyleKit.Units.cornerRadius
    bottomRightRadius: StyleKit.Units.cornerRadius

    // No fill at rest, active or not -- only a hover highlight.
    color: root.active ? "transparent" : (root._hovered ? root.colors.hoverColor : "transparent")

    HoverHandler {
        onHoveredChanged: root._hovered = hovered
    }

    // Off-screen, used only to measure fullWidth above.
    Text {
        id: titleMetrics
        visible: false
        text: root.title
    }

    // アクティブタブの目印になるアクセントライン
    Rectangle {
        visible: root.active && root.activeEdge === "bottom"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.colors.highlightColor
    }

    Rectangle {
        visible: root.active && root.activeEdge === "right"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 2
        color: root.colors.highlightColor
    }

    Row {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: StyleKit.Units.largeSpacing
        anchors.rightMargin: StyleKit.Units.smallSpacing
        spacing: StyleKit.Units.smallSpacing

        Origami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root._composite && root._singleIconName !== ""
            // Symbolic icons are the only ones IconImage actually
            // recolors (see Icon.qml's own class comment) -- a
            // non-symbolic icon just keeps its own theme-baked colors
            // regardless of this.
            color: root.colors.textColor
            opacity: root.active ? 1.0 : 0.7
            source: root._singleIconName
            width: StyleKit.Units.iconSizes.small
            height: StyleKit.Units.iconSizes.small
        }

        // A group tab (iconNames has more than one entry -- see that
        // property's comment) gets a composite in place of the single
        // Icon above, so it reads as visually distinct from an ordinary
        // one-pane tab. Sized by IconStack itself (see its own class
        // comment) -- deliberately no width/height override here, since
        // it needs to grow past one icon's footprint along the tabs'
        // own flow axis as more member icons are shown.
        Origami.IconStack {
            id: iconStack
            anchors.verticalCenter: parent.verticalCenter
            visible: root._composite
            iconNames: root.iconNames
            orientation: root.iconStackOrientation
            color: root.colors.textColor
            opacity: root.active ? 1.0 : 0.7
        }

        Text {
            id: label
            visible: !root.iconOnly
            text: root.title
            color: root.colors.textColor
            opacity: root.active ? 1.0 : 0.7
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Closing a tab is a right-click action instead of a dedicated close
    // button, so the tab strip stays uncluttered (see contextMenu below).
    Origami.ThemedMenu {
        id: contextMenu

        menuItems: [
            {
                text: "閉じる",
                onTriggered: function () {
                    root.closeRequested();
                }
            }
        ]
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // OverlayDrawer(サイドバー)の端のリサイズハンドルや、PaneSplit.qmlで
        // 使っているSplitViewの分割バーは、いずれもFlickableと同様に
        // childMouseEventFilter()でこのMouseAreaが掴んでいるドラッグを途中で
        // 奪おうとしてくる(奪われるとonReleased/onClickedではなくonCanceledが
        // 飛んでくる)。preventStealingでそれを止め、タブのドラッグ中は掴みを
        // 手放さないようにする。
        preventStealing: true

        property real _pressX: 0
        property real _pressY: 0
        property bool _dragging: false

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup();
                return;
            }
            dragArea._pressX = mouse.x;
            dragArea._pressY = mouse.y;
            dragArea._dragging = false;
        }
        onPositionChanged: mouse => {
            if (!dragArea.pressed || (mouse.buttons & Qt.LeftButton) === 0)
                return;
            if (!dragArea._dragging) {
                if (root.controller && root.controller.layoutLocked)
                    return;
                var dx = mouse.x - dragArea._pressX;
                var dy = mouse.y - dragArea._pressY;
                if (Math.hypot(dx, dy) < root.dragThreshold)
                    return;
                dragArea._dragging = true;
                root.controller.beginDrag(root, dragProxy, mouse.x, mouse.y);
            } else {
                var pos = dragArea.mapToItem(root.controller.dragLayer, mouse.x, mouse.y);
                dragProxy.x = pos.x;
                dragProxy.y = pos.y;
            }
        }
        onReleased: {
            if (dragArea._dragging) {
                var targetController = dragProxy.hoverController;
                var targetLeafId = dragProxy.hoverLeafId;
                var zone = dragProxy.hoverZone || "center";
                var targetIndex = dragProxy.hoverTargetIndex;
                if (targetController && targetLeafId >= 0) {
                    if (targetController === root.controller) {
                        if (targetIndex !== undefined && targetIndex >= 0) {
                            targetController.requestDropAtIndex(root.leafId, root.tabId, targetLeafId, targetIndex);
                        } else {
                            targetController.requestDrop(root.leafId, root.tabId, targetLeafId, zone);
                        }
                    } else {
                        var tabData = root.controller.extractTab(root.leafId, root.tabId);
                        if (tabData) {
                            if (targetIndex !== undefined && targetIndex >= 0) {
                                targetController.insertTabAtIndex(tabData, targetLeafId, targetIndex);
                            } else {
                                targetController.insertTab(tabData, targetLeafId, zone);
                            }
                        }
                    }
                }
                dragProxy.hoverController = null;
                dragProxy.hoverLeafId = -1;
                dragProxy.hoverZone = "";
                dragProxy.hoverTargetIndex = -1;
                dragProxy.x = -100000;
                dragProxy.y = -100000;
                root.controller.endDrag(dragProxy);
            }
        }
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && !dragArea._dragging)
                root.clicked();
            dragArea._dragging = false;
        }
        onCanceled: {
            dragProxy.hoverController = null;
            dragProxy.hoverLeafId = -1;
            dragProxy.hoverZone = "";
            dragProxy.hoverTargetIndex = -1;
            dragProxy.x = -100000;
            dragProxy.y = -100000;
            dragArea._dragging = false;
            root.controller.endDrag(dragProxy);
        }

        Item {
            id: dragProxy
            parent: root.controller ? root.controller.dragLayer : root
            visible: false
            width: 1
            height: 1
            z: 1000

            readonly property int tabId: root.tabId
            readonly property int leafId: root.leafId

            property var hoverController: null
            property int hoverLeafId: -1
            property string hoverZone: ""
            property int hoverTargetIndex: -1

            // dragTypeを明示的にInternalにする: 既定のAutomaticのままだと、
            // Wayland環境でQtが実OS(コンポジタ)側のドラッグ&ドロップとして
            // 昇格させようとし、Drag.mimeDataを設定していないこのアプリ内
            // 完結のドラッグでは(entered/exited/positionChangedは来るのに)
            // dropped()が一切発火しない不具合が起きる。Internalにすると
            // QMLシーン内だけで完結する(ウィンドウをまたいだドラッグは
            // そもそも想定していないので問題ない)。
            Drag.dragType: Drag.Internal
            Drag.active: dragArea._dragging
            Drag.keys: ["pane-tab"]
            Drag.hotSpot.x: 0.5
            Drag.hotSpot.y: 0.5

            Rectangle {
                anchors.centerIn: parent
                width: root.width
                height: root.height
                color: root.colors.highlightColor
                opacity: 0.85
                radius: StyleKit.Units.cornerRadius

                Text {
                    anchors.centerIn: parent
                    text: root.title
                    color: root.colors.highlightedTextColor
                }
            }
        }
    }
}
