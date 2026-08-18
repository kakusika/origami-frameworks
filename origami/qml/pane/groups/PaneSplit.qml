import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

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
    readonly property real grabMargin: StyleKit.Units.smallSpacing * 1.5

    // 各子の割合(0〜1)。node.children[i].sizeはプレーンなJSオブジェクトの
    // フィールドで書き換えてもバインディングを再評価させないため、実際の
    // レイアウト計算はこちら(ジェニュインなQMLプロパティ)を経由する。
    // node自体が差し替わった(木の再構築)ときだけnodeから読み直す。
    //
    // Fixed-size children (a collapsed "drawer", or a "toolbar" -- see
    // PaneNode.qml's fixedSizePx) keep their entry here untouched (it
    // still records their relative share for when a collapsed drawer is
    // later re-expanded) -- effectiveSizes below (the actual pixel sizes)
    // is what treats them differently.
    property var sizes: []

    // Index-aligned with node.children: each child's own fixedSizePx (0
    // if it takes a proportional share like an ordinary pane, otherwise
    // the fixed px size it should occupy along this split's axis instead
    // -- see PaneNode.qml's own property for the two cases that currently
    // produce a nonzero value here). Populated by each PaneNode delegate's
    // own onFixedSizePxChanged/Component.onCompleted below, since neither
    // node.children[i].node.expanded (drawer) nor node.type (toolbar)
    // itself has a change notification to bind to directly here.
    //
    // A fixed-size child occupies this size along one axis and the split's
    // full size along the other -- which axis depends on orientation,
    // forced (for a drawer that's a direct child of THIS split) to
    // whichever shape keeps that fixed axis aligned with this split's own
    // resize axis (see PaneDrawer.qml's class comment on
    // splitOrientation/effectiveOrientation: a horizontal split forces a
    // vertical/fixed-width rail, a vertical split forces a horizontal/
    // fixed-height rail; PaneToolbar.qml's own splitOrientation/
    // effectiveOrientation mirror the exact same forcing). Either way the
    // fixed px value itself (StyleKit.Units.collapsedDrawerSize/
    // toolbarSize) is the same regardless of which axis it ends up
    // applied to, so PaneSplit.qml itself never needs to know or care
    // which orientation a given fixed-size child is actually in -- only
    // PaneNode.qml's fixedSizePx (the number) and each leaf's own layout
    // (which axis its *content* reads as "the short one") do. Because of
    // that, a fixed child's px size here always applies along this
    // split's own sizing axis regardless of this
    // split's orientation, so effectiveSizes/_remaining/_expandedSum below
    // apply the fixed-size treatment unconditionally whenever this is
    // nonzero for a given child.
    property var fixedSizes: []

    function _setFixed(index, px) {
        var next = root.fixedSizes.slice();
        while (next.length <= index)
            next.push(0);
        next[index] = px;
        root.fixedSizes = next;
    }

    function _refreshSizes() {
        root.sizes = root.node ? root.node.children.map(function (c) {
            return c.size;
        }) : [];
        // Stale otherwise: a tree rebuild recreates every PaneNode
        // delegate below (fresh onCompleted calls repopulate this
        // correctly), but until then this avoids reading old sizes
        // against a new child list.
        root.fixedSizes = [];
    }

    onNodeChanged: root._refreshSizes()
    Component.onCompleted: root._refreshSizes()

    function _remaining() {
        var total = root.horizontal ? root.width : root.height;
        var fixedTotal = 0;
        for (var i = 0; i < root.fixedSizes.length; i++)
            fixedTotal += root.fixedSizes[i] || 0;
        return Math.max(0, total - fixedTotal);
    }

    function _expandedSum() {
        if (!root.node)
            return 0;
        var sum = 0;
        for (var i = 0; i < root.node.children.length; i++) {
            if (!root.fixedSizes[i])
                sum += root.sizes[i] || 0;
        }
        return sum;
    }

    // Actual pixel size of each child along the split's axis. A
    // fixed-size child (see fixedSizes' own comment above) gets exactly
    // its own fixedSizePx. The remaining space (total minus every
    // fixed-size child's own share) is split among the rest in proportion
    // to their raw `sizes` fraction relative to each other (i.e.
    // normalized against just their own sum, not the full 1.0 budget
    // those fractions add up to across *all* children).
    readonly property var effectiveSizes: {
        var result = [];
        if (!root.node)
            return result;
        var children = root.node.children;
        var remaining = root._remaining();
        var expandedSum = root._expandedSum();
        var expandedCount = children.length - root.fixedSizes.filter(function (c) {
            return !!c;
        }).length;
        for (var i = 0; i < children.length; i++) {
            if (root.fixedSizes[i]) {
                result.push(root.fixedSizes[i]);
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

        delegate: Origami.PaneNode {
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

            onFixedSizePxChanged: root._setFixed(cell.index, cell.fixedSizePx)
            Component.onCompleted: root._setFixed(cell.index, cell.fixedSizePx)
        }
    }

    Repeater {
        model: root.node ? Math.max(0, root.node.children.length - 1) : 0

        delegate: Item {
            id: handleArea
            required property int index

            readonly property real boundary: root._offset(index + 1)

            // Nothing meaningful to drag against a fixed-size neighbor
            // (a collapsed drawer or a toolbar) -- hides the handle and
            // (since invisible items don't receive input) disables its
            // MouseArea too. See fixedSizes' own comment above for why a
            // fixed-size child's size is always along this split's axis
            // regardless of orientation.
            visible: !(root.fixedSizes[handleArea.index] || root.fixedSizes[handleArea.index + 1])

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
