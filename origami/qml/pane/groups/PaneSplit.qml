import QtQuick
import la.cettila.Origami 1.0

// splitノードの表示。
//
// QtQuick.ControlsのSplitViewは、ハンドルの当たり判定がハンドルの表示
// サイズ(=ペイン間に確保されるレイアウト上の隙間)と直結しており、
// 見た目の線の太さは変えずに当たり判定だけを太くすることができない
// (ハンドルのimplicitWidth/Heightを大きくすると、その分だけペイン間の
// 隙間自体が広がって見た目が変わってしまう)。そのため、SplitViewは
// 使わずレイアウトとドラッグを自前で実装し、見た目は細い線1本のまま、
// ドラッグ開始判定の領域だけをその周囲に広く取る。
//
// 子のサイズは、次回の木の複製・再構築時の初期サイズとして使うため
// controller.setSplitSizes()経由でnode.children[i].sizeへ書き戻す
// (このsplitがネストしている場合、root.node自体が親splitのRepeaterの
// modelData経由で渡されたコピーであり、ここへ直接書き込んでも本体の
// root.tree側には反映されないため、必ずidベースでcontrollerに書き戻す
// -- setCurrentTab()のコメント参照)。ドラッグ中の実際の表示更新は、
// 書き戻しとは別に持つroot.sizes(実在するQMLプロパティ)経由で行う。
Item {
    id: root
    property var node
    property var controller

    readonly property bool horizontal: node && node.orientation === "horizontal"
    readonly property real minChildSize: root.horizontal ? 80 : 60
    // ドラッグの当たり判定の半幅。見た目の線の太さには影響しない。
    readonly property real grabMargin: Units.smallSpacing * 1.5

    // 各子の割合(0〜1)。node.children[i].sizeはプレーンなJSオブジェクトの
    // フィールドで書き換えてもバインディングを再評価させないため、実際の
    // レイアウト計算はこちら(ジェニュインなQMLプロパティ)を経由する。
    // node自体が差し替わった(木の再構築)ときだけnodeから読み直す。
    //
    // Collapsed "drawer" children keep their entry here untouched (it
    // still records their relative share for when they're re-expanded
    // later) -- collapse/expand never rewrites this array. Only
    // effectiveSizes below (the actual pixel sizes) treats them
    // differently.
    property var sizes: []

    // Index-aligned with node.children: true where that child is a
    // currently-collapsed "drawer" (see PaneNode.qml's collapsedDrawer).
    // Populated by each PaneNode delegate's own onCollapsedDrawerChanged/
    // Component.onCompleted below, since node.children[i].node.expanded
    // itself has no change notification to bind to directly.
    //
    // A collapsed drawer child's own rail is fixed-size along one axis
    // and full-size along the other -- which axis depends on its
    // orientation, forced (for a drawer that's a direct child of THIS
    // split) to whichever shape keeps that fixed axis aligned with this
    // split's own resize axis (see PaneDrawer.qml's class comment on
    // splitOrientation/effectiveOrientation: a horizontal split forces a
    // vertical/fixed-width rail, a vertical split forces a horizontal/
    // fixed-height rail). Because of that forced pairing, a collapsed
    // drawer child's fixed dimension always matches this split's own
    // sizing axis regardless of orientation, so effectiveSizes/_remaining/
    // _expandedSum below apply the fixed-size treatment unconditionally
    // whenever this is true for a given child.
    property var collapsedFlags: []

    function _setCollapsed(index, value) {
        var next = root.collapsedFlags.slice();
        while (next.length <= index)
            next.push(false);
        next[index] = value;
        root.collapsedFlags = next;
    }

    function _refreshSizes() {
        root.sizes = root.node ? root.node.children.map(function (c) {
            return c.size;
        }) : [];
        // Stale otherwise: a tree rebuild recreates every PaneNode
        // delegate below (fresh onCompleted calls repopulate this
        // correctly), but until then this avoids reading old flags
        // against a new child list.
        root.collapsedFlags = [];
    }

    onNodeChanged: root._refreshSizes()
    Component.onCompleted: root._refreshSizes()

    function _remaining() {
        var total = root.horizontal ? root.width : root.height;
        var collapsedCount = 0;
        for (var i = 0; i < root.collapsedFlags.length; i++) {
            if (root.collapsedFlags[i])
                collapsedCount++;
        }
        return Math.max(0, total - collapsedCount * Units.collapsedDrawerSize);
    }

    function _expandedSum() {
        if (!root.node)
            return 0;
        var sum = 0;
        for (var i = 0; i < root.node.children.length; i++) {
            if (!root.collapsedFlags[i])
                sum += root.sizes[i] || 0;
        }
        return sum;
    }

    // Actual pixel size of each child along the split's axis. A collapsed
    // drawer child gets a fixed Units.collapsedDrawerSize -- see
    // collapsedFlags' own comment above for why that's always this
    // split's own sizing axis, regardless of this split's orientation.
    // The remaining space (total minus every collapsed child's fixed
    // size) is split among the non-collapsed children in proportion to
    // their raw `sizes` fraction relative to each other (i.e. normalized
    // against just their own sum, not the full 1.0 budget those
    // fractions add up to across *all* children).
    readonly property var effectiveSizes: {
        var result = [];
        if (!root.node)
            return result;
        var children = root.node.children;
        var remaining = root._remaining();
        var expandedSum = root._expandedSum();
        var expandedCount = children.length - root.collapsedFlags.filter(function (c) {
            return c;
        }).length;
        for (var i = 0; i < children.length; i++) {
            if (root.collapsedFlags[i]) {
                result.push(Units.collapsedDrawerSize);
            } else if (expandedSum > 0) {
                result.push((root.sizes[i] || 0) / expandedSum * remaining);
            } else {
                result.push(remaining / Math.max(1, expandedCount));
            }
        }
        return result;
    }

    function _offset(index) {
        var sum = 0;
        for (var i = 0; i < index; i++)
            sum += root.effectiveSizes[i];
        return sum;
    }

    function _size(index) {
        return root.effectiveSizes[index];
    }

    Repeater {
        model: root.node ? root.node.children : []

        delegate: PaneNode {
            id: cell
            required property var modelData
            required property int index

            x: root.horizontal ? root._offset(index) : 0
            y: root.horizontal ? 0 : root._offset(index)
            width: root.horizontal ? root._size(index) : root.width
            height: root.horizontal ? root.height : root._size(index)

            node: cell.modelData.node
            controller: root.controller
            splitOrientation: root.node ? root.node.orientation : ""

            onCollapsedDrawerChanged: root._setCollapsed(cell.index, cell.collapsedDrawer)
            Component.onCompleted: root._setCollapsed(cell.index, cell.collapsedDrawer)
        }
    }

    Repeater {
        model: root.node ? Math.max(0, root.node.children.length - 1) : 0

        delegate: Item {
            id: handleArea
            required property int index

            readonly property real boundary: root._offset(index + 1)

            // Nothing meaningful to drag against a fixed-size collapsed
            // neighbor -- hides the handle and (since invisible items
            // don't receive input) disables its MouseArea too. See
            // collapsedFlags' own comment above for why a collapsed
            // drawer child is always fixed-size along this split's axis
            // regardless of orientation.
            visible: !(root.collapsedFlags[handleArea.index] || root.collapsedFlags[handleArea.index + 1])

            x: root.horizontal ? handleArea.boundary - root.grabMargin : 0
            y: root.horizontal ? 0 : handleArea.boundary - root.grabMargin
            width: root.horizontal ? root.grabMargin * 2 : root.width
            height: root.horizontal ? root.height : root.grabMargin * 2
            z: 1

            MouseArea {
                anchors.fill: parent
                enabled: !(root.controller && root.controller.resizeLocked)
                cursorShape: root.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor
                hoverEnabled: false

                property real startPos: 0
                property real startSizeA: 0
                property real startSizeB: 0

                onPressed: mouse => {
                    var p = handleArea.mapToItem(root, mouse.x, mouse.y);
                    startPos = root.horizontal ? p.x : p.y;
                    startSizeA = root.sizes[handleArea.index];
                    startSizeB = root.sizes[handleArea.index + 1];
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    // The two dragged children are only ever rendered
                    // across `remaining` px (not the split's full size)
                    // once some sibling elsewhere is collapsed, and
                    // their combined fraction budget is `expandedSum`
                    // (not the full 1.0) -- both plain 1:1 (remaining ===
                    // total, expandedSum === 1) when nothing is
                    // collapsed, same as before. Derived from
                    // effectiveSize = (size / expandedSum) * remaining.
                    var remaining = root._remaining();
                    var expandedSum = root._expandedSum();
                    if (remaining <= 0 || expandedSum <= 0)
                        return;
                    var p = handleArea.mapToItem(root, mouse.x, mouse.y);
                    var cur = root.horizontal ? p.x : p.y;
                    var delta = (cur - startPos) / remaining * expandedSum;
                    var a = startSizeA + delta;
                    var b = startSizeB - delta;
                    var minFrac = root.minChildSize / remaining * expandedSum;
                    if (a < minFrac) {
                        b -= (minFrac - a);
                        a = minFrac;
                    }
                    if (b < minFrac) {
                        a -= (minFrac - b);
                        b = minFrac;
                    }
                    if (a < minFrac || b < minFrac)
                        return;

                    var next = root.sizes.slice();
                    next[handleArea.index] = a;
                    next[handleArea.index + 1] = b;
                    root.sizes = next;

                    if (root.controller && root.node && root.node.id !== undefined)
                        root.controller.setSplitSizes(root.node.id, next);
                }
            }
        }
    }
}
