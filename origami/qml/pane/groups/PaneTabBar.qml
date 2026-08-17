import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// 1つのleafに属するタブの一覧を表示する横並びのバー。
Item {
    id: root
    property var node
    property int leafId: -1
    property int currentIndex: 0
    property var controller
    height: StyleKit.Units.gridUnit * 1.6
    // ColumnLayout(PaneLeaf.qml)の主軸(縦)サイズ計算は、Layout.preferredHeight
    // が無ければimplicitHeightにフォールバックする(heightプロパティ自体は
    // 見ない)。これを設定しないと、素のItemであるこのコンポーネントは
    // レイアウト上「高さ0」として扱われ、下のcontentAreaがタブバー分も
    // 含めてペイン全高を占有してしまう(タブバーの見た目上の高さと、
    // レイアウトが確保する高さがずれる)。
    implicitHeight: height

    // Every tab drops its title and shows just its icon once the tabs
    // would actually overflow -- i.e. once their combined full-title width
    // no longer fits in the space before the hamburger buttons on the
    // right (`bar`'s "start" and "end" rows anchor from opposite edges and
    // don't reserve space for each other, see HeaderBarRow.qml, so without
    // this they'd visually run into each other). Deliberately not based on
    // a fixed pane width: that ignores how many tabs exist, so a pane with
    // many tabs could already overflow well before hitting any fixed
    // threshold, while a pane with one short-titled tab never needs to
    // collapse at all.
    readonly property real _tabRowSpacing: 1 // matches the Row in `start` below
    readonly property real _fullTabsWidth: {
        var total = searchField.width;
        for (var i = 0; i < tabRepeater.count; i++) {
            var item = tabRepeater.itemAt(i);
            if (item)
                total += root._tabRowSpacing + item.fullWidth;
        }
        return total;
    }
    readonly property real _availableStartWidth: root.width - bar.endWidth - StyleKit.Units.smallSpacing * 2
    readonly property bool _iconOnly: root._fullTabsWidth > root._availableStartWidth

    signal tabClicked(int index)
    signal tabCloseRequested(int tabId)

    Origami.HeaderBar {
        id: bar
        anchors.fill: parent

        start: [
            // Tight spacing (1px, tabs nearly touching) rather than the
            // HeaderBar start slot's own default Units.smallSpacing --
            // wrapped in its own Row so this one nested item can override
            // that spacing without affecting the hamburger in `end`.
            Row {
                spacing: 1

                // Placeholder for an eventual tab-search/filter feature --
                // not yet wired to real filtering (same scope boundary as
                // Explorer.qml's own not-yet-wired CollapsibleTextFields).
                // Deliberately pinned to its own collapsed/icon-only
                // width (square, matching the hamburger button) rather
                // than given Layout.fillWidth -- the tab strip has no
                // spare room for an inline field, so this only ever shows
                // as the compact icon button; tapping it still opens
                // CollapsibleTextField's own popup for real typing.
                Origami.CollapsibleTextField {
                    id: searchField
                    height: bar.contentHeight
                    width: height
                    iconName: "search"
                    placeholderText: "検索"
                }

                Repeater {
                    id: tabRepeater
                    model: root.node ? root.node.children : []

                    delegate: Origami.PaneTabHeader {
                        id: header
                        required property var modelData
                        required property int index

                        // "tabs" children are wrapped as {node: pane} (see
                        // PaneView.qml), so the actual pane is one level in.
                        height: bar.contentHeight
                        title: header.modelData.node.title
                        tabId: header.modelData.node.id
                        leafId: root.leafId
                        active: header.index === root.currentIndex
                        controller: root.controller
                        iconName: (root.controller && root.controller.iconRegistry) ? (root.controller.iconRegistry[header.modelData.node.viewType] || "") : ""
                        iconOnly: root._iconOnly
                        onClicked: root.tabClicked(header.index)
                        onCloseRequested: root.tabCloseRequested(header.tabId)
                    }
                }
            }
        ]

        // "Convert to drawer" hamburger -- this is the "tabs" group's own
        // strip (as opposed to PaneHeader.qml below it, which belongs to
        // the currently *active pane*, not the group), so this is where a
        // group-level action belongs. A pure action menu (no "current
        // value" to show) but, unlike PaneHeader.qml's menu-bar row or
        // SideTitleBar.qml's icon menus, wants a bordered/button-like
        // look rather than flat -- hence HamburgerButton rather than
        // HeaderMenuButton; see HamburgerButton.qml's own class comment.
        end: [
            // New-tab button: adds another pane to this same "tabs"
            // group, letting the user pick which view type from
            // controller.viewTypeCategories -- same category-grouped,
            // search-filterable picker PaneHeader.qml's own type-switcher
            // uses (see ViewTypePickerButton.qml's own class comment), just
            // added rather than swapped in place (see PaneView.qml's
            // addPaneToTabs()). showChevron: false since this is a pure
            // action button, not a "current value" switcher -- no
            // selectedViewType either, for the same reason.
            Origami.ViewTypePickerButton {
                width: bar.contentHeight
                height: bar.contentHeight
                iconName: "tab-new-symbolic"
                showChevron: false
                visible: root.controller ? (root.controller.viewTypeRegistry || []).length > 0 : false
                categories: root.controller ? root.controller.viewTypeCategories : []

                onViewTypeSelected: (viewType, title) => {
                    if (root.controller && root.node)
                        root.controller.addPaneToTabs(root.node.id, viewType, title);
                }
            },
            Origami.HamburgerButton {
                width: bar.contentHeight
                height: bar.contentHeight
                iconName: "application-menu-symbolic"

                menuItems: [
                    {
                        text: "ドロワーに変更",
                        onTriggered: function () {
                            if (root.controller && root.node)
                                root.controller.setGroupType(root.node.id, "drawer");
                        }
                    },
                    {
                        text: "すべてのタブを閉じる",
                        // Guards root.node.children itself too, not just
                        // root.node -- PaneDrawer.qml's own identical
                        // menu item does (enabled: (root.node &&
                        // root.node.children) ? ...), which this
                        // originally missed. root.node can apparently be
                        // truthy with no `children` of its own at some
                        // reachable moment (this crashed live -- "Value
                        // is undefined and could not be converted to an
                        // object" -- reading `.length` off `undefined`
                        // here, confirming `root.node.children` itself,
                        // not just root.node, needs the guard).
                        enabled: (root.node && root.node.children) ? root.node.children.length > 0 : false,
                        // Deferred via Qt.callLater -- unlike every other
                        // action here, this one can destroy this very
                        // HamburgerButton/ThemedMenu's own hosting
                        // PaneTabBar as a side effect (emptying the group
                        // rebuilds root.tree, which this button's own
                        // `menuItems` binding above reads through
                        // root.node). Running that synchronously from
                        // inside the menu's own onTriggered -- while
                        // ThemedMenu/QQC2.Menu is still mid-click-handling
                        // on the very item that triggered it -- crashed
                        // live with "Value is undefined and could not be
                        // converted to an object" reading root.node right
                        // above. Capturing controller/id now, before
                        // deferring, since by the time this actually runs
                        // next tick nothing guarantees root/root.node are
                        // still the same (same precaution
                        // HamburgerButton.qml's own Qt.callLater usage
                        // documents for this general class of Menu/
                        // Repeater fragility).
                        onTriggered: function () {
                            if (!root.controller || !root.node)
                                return;
                            var controller = root.controller;
                            var id = root.node.id;
                            Qt.callLater(function () {
                                controller.closeAllTabs(id);
                            });
                        }
                    },
                    {
                        text: "タブグループを閉じる",
                        // See "すべてのタブを閉じる" above for why this is
                        // deferred -- closing the whole group is an even
                        // more direct case of the same self-destruction
                        // hazard (this removes the group -- and therefore
                        // this very menu's own hosting PaneTabBar --
                        // entirely).
                        onTriggered: function () {
                            if (!root.controller || !root.node)
                                return;
                            var controller = root.controller;
                            var id = root.node.id;
                            Qt.callLater(function () {
                                controller.closeGroup(id);
                            });
                        }
                    }
                ]
            }
        ]
    }
}
