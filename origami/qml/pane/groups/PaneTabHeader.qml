import QtQuick
import la.cettila.Origami 1.0

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

    // Renders as a small grip glyph instead of the title+close row, with
    // no close button. Used by PaneTabs.qml for the drag handle pinned
    // to the pane's top-left corner: same drag/drop mechanics as a normal
    // tab header below, just a different, fixed-size look.
    property bool compact: false

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
    // every tab to show its full title. No effect when compact (that
    // mode never shows a title to begin with).
    property bool iconOnly: false

    // Width this tab would take with its title shown, regardless of the
    // current iconOnly value -- used by PaneTabBar.qml to detect whether
    // the full tab row would actually overflow the available space (see
    // its own _iconOnly comment). Deliberately independent of iconOnly so
    // that binding doesn't create a feedback loop through it. Mirrors the
    // `width:` formula below, but measures the title via titleMetrics
    // (below) instead of contentRow.implicitWidth, since contentRow is a
    // Row and Row excludes invisible children (label when iconOnly) from
    // its own implicitWidth -- exactly the mechanism iconOnly relies on
    // to shrink the visible tab, which is not what we want to measure here.
    // Composite icons grow past one icon's width when they line up
    // horizontally (see IconStack.qml's own class comment), so this has
    // to read the actual iconStack width rather than assume a single
    // icon's worth like the ordinary case.
    readonly property real _iconAreaWidth: root._composite ? iconStack.width : (root._singleIconName !== "" ? Units.iconSizes.small : 0)
    readonly property real fullWidth: root.compact ? root.width : (root._iconAreaWidth > 0 ? root._iconAreaWidth + Units.smallSpacing : 0) + titleMetrics.implicitWidth + Units.largeSpacing * 2

    // 押してからこのpx数だけ動かすまでは、ただのクリックとして扱い
    // ドラッグを開始しない(短いクリックでも半透明のドラッグ像が一瞬
    // 出てしまっていた問題を解消するための、動きの大きさによる判定)。
    // プラットフォーム標準のドラッグ開始距離をそのまま使う。
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
    readonly property var colors: Theme.paletteFor(root.active ? Theme.view : Theme.header)

    // Compact width hugs the dot grid itself (just a little breathing
    // room, no side padding to match a normal tab) so the grip reads as a
    // narrow vertical strip instead of a squarish button.
    width: root.compact ? dotGrid.implicitWidth + Units.smallSpacing : contentRow.implicitWidth + Units.largeSpacing * 2
    // Baseline height comfortably fits one icon's worth of vertical
    // padding. A composite that stacks vertically (IconStack's own
    // `orientation`, PaneDrawer.qml's vertical rail) can grow taller
    // than one icon -- when it does, the tab grows with it instead of
    // clipping/overflowing past its own bounds, using the same padding
    // the single-icon case already has room for.
    readonly property real _iconAreaHeight: root._composite ? iconStack.height : Units.iconSizes.small
    height: Math.max(Units.gridUnit * 1.6, root._iconAreaHeight + (Units.gridUnit * 1.6 - Units.iconSizes.small))

    topLeftRadius: Units.cornerRadius
    topRightRadius: Units.cornerRadius
    bottomLeftRadius: Units.cornerRadius
    bottomRightRadius: Units.cornerRadius

    // No fill at rest, active or not -- only a hover highlight (the
    // active tab is already distinguished by its own accent line below,
    // see the Rectangle right after this one).
    color: root.compact ? (root._hovered ? root.colors.hoverColor : "transparent") : (root.active ? "transparent" : (root._hovered ? root.colors.hoverColor : "transparent"))

    HoverHandler {
        onHoveredChanged: root._hovered = hovered
    }

    // Off-screen, used only to measure fullWidth above -- see that
    // property's comment for why this can't just read label.implicitWidth.
    Text {
        id: titleMetrics
        visible: false
        text: root.title
    }

    // アクティブタブの目印になるアクセントライン(Breeze系のアプリで
    // 見慣れた、現在選択中のタブを示す表現)。compactなグリップは
    // 「選択中のタブ」を示す必要がない(タブ一覧の一部ではない)ので出さない。
    // activeEdge (see its own comment) picks which of these two draws.
    Rectangle {
        visible: root.active && !root.compact && root.activeEdge === "bottom"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        color: root.colors.highlightColor
    }

    Rectangle {
        visible: root.active && !root.compact && root.activeEdge === "right"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 2
        color: root.colors.highlightColor
    }

    // Grip glyph shown instead of the title+close row below when compact.
    // Custom-drawn dots rather than an icon name, so it always renders
    // regardless of the active icon theme (same reasoning as PaneSplit.qml's
    // plain Rectangle-based handle).
    Grid {
        id: dotGrid
        visible: root.compact
        anchors.centerIn: parent
        columns: 2
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 6

            delegate: Rectangle {
                width: 3
                height: 3
                radius: 1.5
                color: root.colors.textColor
                opacity: 0.6
            }
        }
    }

    Row {
        id: contentRow
        visible: !root.compact
        anchors.fill: parent
        anchors.leftMargin: Units.largeSpacing
        anchors.rightMargin: Units.smallSpacing
        spacing: Units.smallSpacing

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root._composite && root._singleIconName !== ""
            // Symbolic icons are the only ones IconImage actually
            // recolors (see Icon.qml's own class comment) -- a
            // non-symbolic icon just keeps its own theme-baked colors
            // regardless of this.
            color: root.colors.textColor
            opacity: root.active ? 1.0 : 0.7
            source: root._singleIconName
            width: Units.iconSizes.small
            height: Units.iconSizes.small
        }

        // A group tab (iconNames has more than one entry -- see that
        // property's comment) gets a composite in place of the single
        // Icon above, so it reads as visually distinct from an ordinary
        // one-pane tab. Sized by IconStack itself (see its own class
        // comment) -- deliberately no width/height override here, since
        // it needs to grow past one icon's footprint along the tabs'
        // own flow axis as more member icons are shown.
        IconStack {
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
    ThemedMenu {
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
                // Drag.drop()には頼らない(PaneDropOverlay.qml参照: MouseAreaの
                // onReleased時点では既にdrag.activeがfalseへ遷移済みで、
                // Drag.drop()を呼んでもdropped()が発火しないことがある)。
                // 代わりに、ホバー中にPaneDropOverlayが書き込んでおいた
                // hoverController/hoverLeafId/hoverZoneを直接使って確定する。
                // ドロップ先が自分自身と同じcontrollerならrequestDrop()、
                // 別のPaneView(サイドバー⇔メインエリアなど別controller)への
                // 移動ならextractTab()で取り出してinsertTab()で挿入する。
                var targetController = dragProxy.hoverController;
                var targetLeafId = dragProxy.hoverLeafId;
                var zone = dragProxy.hoverZone || "center";
                if (targetController && targetLeafId >= 0) {
                    if (targetController === root.controller) {
                        targetController.requestDrop(root.leafId, root.tabId, targetLeafId, zone);
                    } else {
                        var tabData = root.controller.extractTab(root.leafId, root.tabId);
                        if (tabData)
                            targetController.insertTab(tabData, targetLeafId, zone);
                    }
                }
                dragProxy.hoverController = null;
                dragProxy.hoverLeafId = -1;
                dragProxy.hoverZone = "";
                // Drag.activeをfalseにする(onClickedでの_dragging=false)前に、
                // dragProxyをドロップ領域の外へ実際に動かしておく。自ペインへ
                // ドロップした場合のように一度もexited()が発火しないまま
                // ドラッグを終えると、Qt内部のドラッググラバーがそのDropArea
                // へ「入ったまま」の状態を引きずり、次に同じleaf上で(別の
                // タブであっても)ドラッグしてもentered()が二度と発火しなく
                // なる。位置を実際に動かして正規のexited()を発火させることで
                // グラバー側の状態をきちんと後始末する。
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
            // サイドバー(OverlayDrawer、interactiveResizeEnabled)の端に
            // ドラッグ中のポインタが差しかかると、リサイズ判定のために
            // マウスの掴みがこちらから奪われることがある。その場合Qtは
            // released/clickedではなくcanceledを送ってくる。ここで
            // _draggingをリセットしないと、Drag.active(→dragProxyの
            // Drag.active)がtrueのまま固まり、ホバー中だったPaneDropOverlay
            // のハイライトが消えなくなる(以後のペイン移動も巻き添えで
            // 効かなくなる)。
            dragProxy.hoverController = null;
            dragProxy.hoverLeafId = -1;
            dragProxy.hoverZone = "";
            // onReleased同様、Drag.activeを落とす前にdropArea外へ追い出して
            // 正規のexited()を発火させておく(理由は上のonReleased参照)。
            // そのため_draggingのリセットはこの後で行う。
            dragProxy.x = -100000;
            dragProxy.y = -100000;
            dragArea._dragging = false;
            root.controller.endDrag(dragProxy);
        }

        // ドラッグ/ドロップの当たり判定に使う実体。DropArea側の判定は
        // このアイテム自身の矩形(位置+サイズ)とDropAreaの矩形の重なりで
        // 行われるため、タブと同じ大きさのまま(width/height: root.width/
        // root.height)にしていると、画面の端付近へドロップしようとした
        // 瞬間に矩形の一部がウィンドウ外へはみ出し、"entered"は来るのに
        // "dropped"が発火しない(はみ出た瞬間に"exited"扱いされる)不具合が
        // 起きる。そのため当たり判定はカーソル位置そのものを表す1x1の点に
        // 縮小し、見た目の大きさは中の子Rectangle(親の矩形の外にもそのまま
        // 描画される)だけで表現する。
        Item {
            id: dragProxy
            parent: root.controller ? root.controller.dragLayer : root
            visible: false
            width: 1
            height: 1
            z: 1000

            readonly property int tabId: root.tabId
            readonly property int leafId: root.leafId

            // 現在ホバー中のドロップ先(PaneDropOverlay.qmlが書き込む)。
            // Drag.drop()に頼らずonReleasedで直接読むために使う。
            property var hoverController: null
            property int hoverLeafId: -1
            property string hoverZone: ""

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
                radius: Units.cornerRadius

                Text {
                    anchors.centerIn: parent
                    text: root.title
                    color: root.colors.highlightedTextColor
                }
            }
        }
    }
}
