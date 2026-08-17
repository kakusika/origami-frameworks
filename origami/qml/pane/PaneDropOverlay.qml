import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// leaf全面を覆う透明なドロップ領域。ドラッグ中のポインタ位置に応じて
// 上下左右の縁(分割)か中央(タブとして統合)かを判定し、対応する
// ハイライトを表示する。
//
// ドロップの確定はDrag.drop()/dropped()に頼らない: MouseAreaの
// onReleasedが発火する時点ではdrag.active(→dragProxyのDrag.active)が
// 既にfalseへ遷移済みで、そこから呼ぶDrag.drop()が不発になる(dropped
// シグナルが飛ばない)ことがある。代わりに、ホバー中のたびにドラッグ元
// (dragProxy、drag.source)へ「いまどのcontroller/leaf/zoneの上にいるか」
// を書き込んでおき、マウスを離した瞬間にPaneTabHeader.onReleasedが
// それを読んで直接controller.requestDrop()/extractTab()+insertTab()を
// 呼ぶ。exited()にはdragパラメータが来ないため、entered時のdrag.source
// を覚えておいて後始末に使う。
DropArea {
    id: root
    property int leafId: -1
    property var controller
    keys: ["pane-tab"]

    property var _dragSource: null

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // hoverZoneは自前で保持せず、常に_dragSource(dragProxy)側の状態から
    // 導出する。dragProxy側はPaneTabHeader.onReleased/onCanceledでドラッグ
    // 終了時に必ずクリアされるのに対し、このDropArea自身のonExited()は
    // 自ペイン(ドラッグ元と同じleaf)へドロップした場合にポインタが
    // DropAreaの外へ一度も出ないため発火せず、頼っているとハイライトが
    // 表示されたまま残ってしまう。dragProxy側を正とすることで、
    // onExited()の発火有無によらず確実にクリアされるようにする。
    readonly property string hoverZone: (root._dragSource && root._dragSource.hoverController === root.controller && root._dragSource.hoverLeafId === root.leafId) ? root._dragSource.hoverZone : ""

    function _updateHoverTarget(drag, zone) {
        root._dragSource = drag.source;
        if (drag.source) {
            drag.source.hoverController = root.controller;
            drag.source.hoverLeafId = root.leafId;
            drag.source.hoverZone = zone;
        }
    }

    // ドラッグ中のタブがこの葉自身から出たものであっても、辺ゾーン
    // (分割)は上下左右を区別せず許可する: 複数タブがまとまったleafから
    // 1つだけ外へ split して独立させる、という正当な操作になり得る
    // ため(これを一律centerにブロックすると、一度タブがグループ化
    // されたleafはもう二度と分割できなくなってしまう)。centerでの
    // 自己ドロップ(自分自身のタブバーへ戻すだけ)はrequestDrop()側で
    // 引き続き無視される。
    //
    // ただし、ドラッグ元が単体の(グループ化されていない)paneで、かつ
    // その自分自身へのセルフドロップの場合は例外: 辺ゾーンであっても
    // requestDrop()側で無条件にno-opされる(隣に割って残す相手がそもそも
    // 存在しないため)。それを知らずにここでハイライトだけ出すと、
    // ユーザーには分割できそうに見えるのに離しても何も起きない、という
    // 見た目と実際の挙動が食い違う状態になるため、その場合はゾーンなし
    // (ハイライト非表示)にする。
    function _zoneFor(x, y, drag) {
        if (drag.source && drag.source.leafId === root.leafId && root.controller && root.controller.isStandalonePane(root.leafId))
            return "";
        return root._rawZoneFor(x, y);
    }

    // drawerEdge carves out a thin sliver right at the very top/bottom
    // edge, inside the outer "top"/"bottom" split band -- dropping there
    // produces a collapsible "drawer" group (see PaneView.qml's class
    // comment) instead of a plain vertical "split". Checked before the
    // wider "top"/"bottom" bands so the sliver wins within their shared
    // region.
    readonly property real drawerEdge: 14

    function _rawZoneFor(x, y) {
        var edge = Math.min(width, height) * 0.28;
        edge = Math.min(edge, 90);
        if (x < edge)
            return "left";
        if (x > width - edge)
            return "right";
        if (y < root.drawerEdge)
            return "drawer-top";
        if (y < edge)
            return "top";
        if (y > height - root.drawerEdge)
            return "drawer-bottom";
        if (y > height - edge)
            return "bottom";
        return "center";
    }

    onPositionChanged: drag => {
        drag.accept();
        root._updateHoverTarget(drag, root._zoneFor(drag.x, drag.y, drag));
    }
    onEntered: drag => {
        // 明示的にaccept()しないと、entered/exited/positionChangedが
        // 来なくなる(dragが「受理」されなかった扱いになる)。
        drag.accept();
        root._updateHoverTarget(drag, root._zoneFor(drag.x, drag.y, drag));
    }
    onExited: {
        if (root._dragSource && root._dragSource.hoverController === root.controller && root._dragSource.hoverLeafId === root.leafId) {
            root._dragSource.hoverController = null;
            root._dragSource.hoverLeafId = -1;
            root._dragSource.hoverZone = "";
        }
        root._dragSource = null;
    }

    // "drawer-top"/"drawer-bottom" get their own thin highlight (rather
    // than sharing the half-height "top"/"bottom" one below) so the two
    // zones read as visually distinct: this one previews a collapsible
    // group at the exact edge sliver that produces it, instead of a
    // half-and-half split.
    Rectangle {
        visible: root.containsDrag && (root.hoverZone === "drawer-top" || root.hoverZone === "drawer-bottom")
        color: root.colors.positiveTextColor
        opacity: 0.4
        border.color: root.colors.positiveTextColor
        border.width: 2

        x: 0
        y: root.hoverZone === "drawer-bottom" ? root.height - root.drawerEdge : 0
        width: root.width
        height: root.drawerEdge
    }

    Rectangle {
        visible: root.containsDrag && (root.hoverZone !== "" && root.hoverZone !== "drawer-top" && root.hoverZone !== "drawer-bottom")
        color: root.colors.highlightColor
        opacity: 0.35
        border.color: root.colors.highlightColor
        border.width: 2

        x: root.hoverZone === "right" ? root.width / 2 : 0
        y: root.hoverZone === "bottom" ? root.height / 2 : 0
        width: (root.hoverZone === "left" || root.hoverZone === "right") ? root.width / 2 : root.width
        height: (root.hoverZone === "top" || root.hoverZone === "bottom") ? root.height / 2 : root.height
    }
}
