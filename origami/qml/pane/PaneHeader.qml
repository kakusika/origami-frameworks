import QtQuick
import la.cettila.Origami 1.0

// Blender-style header shown above a leaf's content area (see
// PaneLeaf.qml). Built on the generic MultiRowHeaderBar.qml shell --
// everything currently lives in the `start` slot (drag grip, view-type
// switcher, menu buttons), left-aligned exactly as before HeaderBar
// existed; `end` is left empty for now. Renders a row of menu
// buttons, each opening a popup menu. A view can supply its own real menus
// by exposing a `paneHeaderMenus` property (same optional-interface
// pattern as paneSerialize/paneRestore): an array of { text, items },
// where each item is either a plain string (inert placeholder) or
// { text, onTriggered } (an actual action). This is merged (see
// `_mergeMenus`/`_effectiveMenus` below) with a builtin "表示" submenu
// (別ウィンドウで開く/別ウィンドウに移動, via PaneWindow.qml) present on
// every pane regardless of view type -- a view's own "表示" entry, if any
// (e.g. Explorer/BoardView's own "ペインを最大化"), gets these appended
// into it rather than a second separate "表示" submenu appearing.
//
// A view may additionally expose a `paneHeaderExtraRows` property -- an
// array of already-built Items, one per additional row (typically each a
// Row/RowLayout of its own controls, e.g. a tool's options -- mirrors
// Blender's per-editor tool-header row(s)), shown below the menu row in
// array order. This is why MultiRowHeaderBar.qml (not plain
// HeaderBar.qml) backs this component: when a view doesn't supply any,
// `extraRows` below is empty and MultiRowHeaderBar collapses to exactly
// the same single-row height HeaderBar would have given it, so this
// switch is invisible to every existing view.
//
// A view may also expose a `paneHeaderCenter` property -- same
// already-built-Items shape as paneHeaderExtraRows, but placed in this
// header's own top-row `center` slot (HeaderBarRow.qml's `centerRow`,
// centered across the header's full width) instead of a row of its own.
// For a single quick-access button (e.g. Map's background-image picker)
// rather than a whole row of controls.
//
// A view may similarly expose a `paneHeaderEnd` property -- same shape
// again, placed in the top row's own `end` slot (HeaderBarRow.qml's
// `endRow`, right-aligned) instead of the centered one. For a control that
// belongs at the header's trailing edge rather than its center (e.g. Map's
// overlay-visibility toggle).
//
// A view may also expose a `paneHeaderModeSwitch` property -- same
// already-built-Items shape again, but spliced into the `start` row itself
// (see `_startLeading`/`_startTrailing`/`start` below), right after the
// pane-type switcher (`typeButton`) and before the menu buttons. For a
// control that changes which underlying data source/mode a view is showing
// (e.g. Map's image-vs-OSM switch) -- a sibling of the pane-type switcher
// rather than a generic toolbar button, so it belongs at that exact
// position, not center/end.
MultiRowHeaderBar {
    id: root

    // MultiRowHeaderBar/HeaderBar are pure layout with no background of
    // their own (see their class comments) -- this header is the one
    // caller that actually wants the themed look, so it owns the palette
    // lookup and the Rectangle below instead.
    readonly property var colors: Theme.paletteFor(Theme.header)

    // Reads root._activeTab.item directly here (rather than depending on
    // it) wouldn't work: pane.item is a plain JS field set by
    // controller.materialize(), not a real QML property, so assigning it
    // fires no change notification and this binding would never
    // re-evaluate once the pane's item actually appears. Calling
    // materialize() here instead guarantees the item exists (it's a
    // no-op if some other code, e.g. PaneLeaf, already created it) at the
    // moment _activeTab itself changes, which *is* a tracked dependency.
    // Shared by both optional interfaces below (paneHeaderMenus/
    // paneHeaderExtraRow) so there's one materialize() call, not two.
    readonly property var _activeItem: (root._activeTab && root.controller) ? root.controller.materialize(root._activeTab) : null

    Component {
        id: paneWindowComponent
        PaneWindow {}
    }

    // "別ウィンドウで開く": a fresh instance of the active pane's own view
    // type, in a brand-new PaneWindow -- the existing pane is untouched.
    //
    // Parented to root.controller (the PaneView instance, alive for the
    // whole app session), not root (this PaneHeader) -- Component.
    // createObject(parent, ...) makes the new object a QObject child of
    // parent for C++ ownership purposes, and this PaneHeader can be
    // destroyed well before the new window should be (trivially so for
    // _moveActiveToNewWindow below, which closes this very pane right
    // after; parenting to root here too for the same reason/consistency,
    // since panes can be closed/split from elsewhere at any time).
    function _openActiveInNewWindow() {
        if (!root._activeTab || !root.controller)
            return;
        var component = root.controller.componentRegistry ? root.controller.componentRegistry[root._activeTab.viewType] : null;
        if (!component)
            return;
        paneWindowComponent.createObject(root.controller, {
            paneComponent: component,
            title: root._activeTab.title,
            paneViewType: root._activeTab.viewType
        });
    }

    // "別ウィンドウに移動": the active pane's own already-live Item, moved
    // (not recreated) into a new PaneWindow -- see PaneView.detachPane()'s
    // own comment for why creating the window (which reparents the Item
    // synchronously via its initial `hostedItem` property) has to happen
    // before detachPane()/closeTab() runs, not after.
    function _moveActiveToNewWindow() {
        if (!root._activeTab || !root.controller || !root._activeItem || !root.node)
            return;
        var item = root._activeItem;
        var title = root._activeTab.title;
        var viewType = root._activeTab.viewType;
        var areaId = root.node.id;
        var paneId = root._activeTab.id;
        paneWindowComponent.createObject(root.controller, {
            hostedItem: item,
            title: title,
            paneViewType: viewType
        });
        root.controller.detachPane(areaId, paneId);
    }

    readonly property var _builtinMenus: [
        {
            text: "表示",
            items: [
                {
                    text: "別ウィンドウで開く",
                    onTriggered: function () {
                        root._openActiveInNewWindow();
                    }
                },
                {
                    text: "別ウィンドウに移動",
                    onTriggered: function () {
                        root._moveActiveToNewWindow();
                    }
                }
            ]
        }
    ]

    // Merges builtinMenus into viewMenus: a top-level entry with a matching
    // `text` and `items` (e.g. both calling it "表示") gets builtinMenus'
    // items appended into the *existing* entry rather than producing a
    // second separate submenu of the same name; anything builtinMenus has
    // that viewMenus doesn't is appended as its own new top-level entry.
    function _mergeMenus(viewMenus, builtinMenus) {
        var result = viewMenus.slice();
        for (var i = 0; i < builtinMenus.length; i++) {
            var builtin = builtinMenus[i];
            var existingIdx = -1;
            for (var j = 0; j < result.length; j++) {
                if (result[j].text === builtin.text && result[j].items) {
                    existingIdx = j;
                    break;
                }
            }
            if (existingIdx !== -1)
                result[existingIdx] = {
                    text: result[existingIdx].text,
                    items: result[existingIdx].items.concat(builtin.items)
                };
            else
                result.push(builtin);
        }
        return result;
    }

    readonly property var _effectiveMenus: root._mergeMenus((root._activeItem && root._activeItem.paneHeaderMenus) ? root._activeItem.paneHeaderMenus : [], root._builtinMenus)

    // Shared "seamless hover switch" coordinator (see HeaderMenuCoordinator.
    // qml's own class comment) for every menu-opening control in this
    // header's own start row -- the view-type switcher (typeButton), any
    // paneHeaderModeSwitch items, and HeaderMenuGroup's own File/Edit-style
    // menus all report through this one instance, so hovering across any
    // of them while another is open swaps which one is showing, not just
    // within HeaderMenuGroup's own menus.
    readonly property QtObject _menuCoordinator: HeaderMenuCoordinator {}

    // Items already wired to _menuCoordinator (see _wireMenuCoordinator
    // below) -- guards against double-connecting the same view-supplied
    // paneHeaderModeSwitch item's signals. Unlike typeButton (a single,
    // static declaration below), _modeSwitchItems is a binding that
    // re-evaluates on every _activeItem change, including switching back
    // to a tab whose view instance (and therefore whose
    // paneHeaderModeSwitch items) was already materialized and wired
    // once before.
    property var _wiredModeSwitchItems: []

    // Connects one paneHeaderModeSwitch item's opened/closed/hovered
    // signals to _menuCoordinator, the same three hookups HeaderMenuGroup.
    // qml's own Repeater delegate makes declaratively for its buttons --
    // done imperatively here instead since these items come from an
    // externally-supplied array, not a delegate this file controls.
    // Silently skipped for anything that doesn't match the
    // HeaderMenuButton/DropdownButton/HamburgerButton shape (opened/
    // closed signals, requestOpen()/requestClose() functions), so a view
    // supplying a plain non-menu Item as paneHeaderModeSwitch still works.
    function _wireMenuCoordinator(item) {
        if (!item || root._wiredModeSwitchItems.indexOf(item) !== -1)
            return;
        if (typeof item.requestOpen !== "function" || typeof item.requestClose !== "function")
            return;
        root._wiredModeSwitchItems.push(item);
        // `item` belongs to the *view's* own object tree (whatever
        // supplied paneHeaderModeSwitch), not this PaneHeader's -- these
        // imperative connect()s aren't torn down automatically the way a
        // declarative `onSignal:` handler on a child of `root` would be
        // (see typeButton's own onOpened/onClosed/onHoveredChanged below
        // for that contrast). If `item`'s underlying view outlives this
        // PaneHeader even briefly during a pane close (e.g. closeGroup()/
        // closeAllTabs() tearing down several leaves' headers at once),
        // one of these can still fire after `root` itself has already
        // been destroyed -- QML nulls out a destroyed QObject's own
        // references, so `root` reads back as null rather than throwing;
        // guard against that instead of dereferencing it blindly.
        item.opened.connect(function () {
            if (root)
                root._menuCoordinator.noteOpened(item);
        });
        item.closed.connect(function () {
            if (root)
                root._menuCoordinator.noteClosed(item);
        });
        item.hoveredChanged.connect(function () {
            if (root && item.hovered)
                root._menuCoordinator.noteHovered(item);
        });
    }

    // A view building paneHeaderCenter/paneHeaderEnd/paneHeaderModeSwitch
    // items has no way to reach this file's own `root.contentHeight` --
    // that `root` refers to the view's own root, a different scope
    // entirely -- so left to their own devices those items each guess at
    // a height (or fall back to their own implicitHeight), which drifts
    // from grip/typeButton/HeaderMenuGroup's own `height: root.contentHeight`
    // by a few px and reads as inconsistent vertical padding/size next to
    // them. Rebinding `height` here, once, right where each item is
    // received, means a view never needs to know or guess this file's own
    // sizing at all. Qt.binding() (not a plain assignment) so the item
    // keeps tracking contentHeight if it ever changes, not just its value
    // at the moment this runs.
    function _withHeaderHeight(items) {
        items.forEach(function (item) {
            item.height = Qt.binding(function () {
                return root.contentHeight;
            });
        });
        return items;
    }

    // See this file's class comment for what paneHeaderModeSwitch is.
    // Each item is also wired into _menuCoordinator (see its own comment
    // above) so it shares hover-switch behavior with typeButton and
    // HeaderMenuGroup below, not just with its own paneHeaderModeSwitch
    // siblings.
    readonly property var _modeSwitchItems: {
        var items = root._withHeaderHeight((root._activeItem && root._activeItem.paneHeaderModeSwitch) ? root._activeItem.paneHeaderModeSwitch : []);
        items.forEach(root._wireMenuCoordinator);
        return items;
    }

    // x-offset within startRow where HeaderMenuGroup itself begins: the
    // row's own left margin plus each preceding visible item's width and
    // its trailing inter-item spacing (grip, typeButton, modeSwitchSlot).
    // Shared by _menuGroupAvailableWidth below both to size HeaderMenuGroup
    // against the header's right edge and to size it against center's own
    // left edge.
    readonly property real _startPrefixWidth: Units.smallSpacing + (grip.visible ? grip.width + Units.smallSpacing : 0) + (typeButton.visible ? typeButton.width + Units.smallSpacing : 0) + (modeSwitchSlot.width > 0 ? modeSwitchSlot.width + Units.smallSpacing : 0)

    // How much horizontal room is left for HeaderMenuGroup, passed to its
    // own availableWidth so it can collapse into a single hamburger button
    // instead of silently overflowing this pane's own right edge once a
    // split/tabbed layout has made it narrow -- capped by two independent
    // limits, the smaller one wins:
    //
    // - room before this header's own right edge (mirrors HeaderBarRow.qml's
    //   own left/right margins, Units.smallSpacing each, so this comes out
    //   flush with how startRow actually lays these items out)
    // - room before center's own left edge, when center has content
    //   (paneHeaderCenter, e.g. MapView.qml's image/OSM switch) -- center is
    //   independently centered (HeaderBarRow.qml's own class comment: start/
    //   end "reserve no space" for it), so without this second limit,
    //   HeaderMenuGroup only collapses once it already overflows past this
    //   header's own right edge, which can be well after it has already
    //   visually run into center.
    readonly property real _menuGroupAvailableWidth: {
        var rightEdgeBudget = Math.max(0, root.width - root._startPrefixWidth - Units.smallSpacing);
        if (root.centerWidth <= 0)
            return rightEdgeBudget;
        var centerLeftEdge = (root.width - root.centerWidth) / 2;
        var centerEdgeBudget = Math.max(0, centerLeftEdge - root._startPrefixWidth - Units.smallSpacing);
        return Math.min(rightEdgeBudget, centerEdgeBudget);
    }

    // See this file's class comment for what paneHeaderExtraRows is.
    // Passed straight through to MultiRowHeaderBar.extraRows -- both are
    // already the same shape (a plain array of Items, one per row).
    readonly property var _extraRows: (root._activeItem && root._activeItem.paneHeaderExtraRows) ? root._activeItem.paneHeaderExtraRows : []
    extraRows: root._extraRows

    // See this file's class comment for what paneHeaderCenter is.
    readonly property var _centerItems: root._withHeaderHeight((root._activeItem && root._activeItem.paneHeaderCenter) ? root._activeItem.paneHeaderCenter : [])
    center: root._centerItems

    // See this file's class comment for what paneHeaderEnd is.
    readonly property var _endItems: root._withHeaderHeight((root._activeItem && root._activeItem.paneHeaderEnd) ? root._activeItem.paneHeaderEnd : [])
    end: root._endItems

    // Pane context, needed only for the drag grip below.
    property var node
    property var controller
    property int leafId: -1
    property int currentIndex: 0

    // The pane whose content is currently displayed: the node itself if
    // it's a standalone "pane", or the active child if it's a "tabs" node
    // (see PaneView.qml; "tabs" children are wrapped as {node: pane}).
    readonly property var _activeTab: {
        if (!root.node)
            return null;
        if (root.node.type === "tabs")
            return (root.currentIndex < root.node.children.length) ? root.node.children[root.currentIndex].node : null;
        if (root.node.type === "pane")
            return root.node;
        return null;
    }

    // Looked up from controller.iconRegistry (viewType -> icon name, set
    // up in main.qml) rather than stored on the tab itself, since a tab's
    // icon is a property of its viewType, not of that particular instance.
    readonly property string _activeIcon: (root.controller && root.controller.iconRegistry && root._activeTab) ? (root.controller.iconRegistry[root._activeTab.viewType] || "") : ""

    // Whether this header's own leaf (a standalone "pane", or a "tabs"
    // node -- either way, one split/drawer cell; see PaneLeaf.qml's own
    // TapHandler for how activeLeafId gets set) is the one the user last
    // clicked into. Drawn as an accent line at the bottom of this header
    // rather than a border around the whole pane: a plain standalone
    // "pane" is deliberately borderless (see PaneNode.qml's class
    // comment on framing), so a border here would be inconsistent with
    // that -- but every leaf, framed or not, has this header, so an
    // accent line here reaches both cases the same way PaneTabHeader.qml
    // already marks the active *tab*.
    readonly property bool _active: !!root.controller && root.leafId === root.controller.activeLeafId

    // Background: MultiRowHeaderBar itself draws nothing (see its class
    // comment), so this header supplies its own -- z: -1 rather than
    // relying on declaration order, since this Rectangle is declared
    // after (and would otherwise paint over) the base type's own
    // top row/extraRows Column.
    Rectangle {
        z: -1
        anchors.fill: parent
        color: root.colors.backgroundColor
        radius: Units.cornerRadius
    }

    start: [
        // Grip handle for the pane's active tab, pinned to the header's
        // top-left corner. Dragging it moves that tab exactly like
        // dragging its own tab-bar header would (PaneTabHeader.qml's
        // `compact` mode shares the same drag/drop mechanics, just a
        // small dot-grip look instead of the title+close row) -- it
        // gives a stable place to grab the pane's current view even
        // while PaneTabs's tab strip below is hidden (single-pane case).
        PaneTabHeader {
            id: grip
            height: root.contentHeight
            compact: true
            // Hidden while layout is locked (LayoutLockSettings), since it
            // exists only to grab-and-move the pane.
            visible: root._activeTab !== null && !(root.controller && root.controller.layoutLocked)
            title: root._activeTab ? root._activeTab.title : ""
            tabId: root._activeTab ? root._activeTab.id : -1
            leafId: root.leafId
            active: true
            controller: root.controller

            // Right-clicking the grip still opens PaneTabHeader's own
            // "閉じる" context menu (compact only hides the drag glyph's
            // look, not that menu -- see PaneTabHeader.qml's own
            // `compact` comment). Without this handler closeRequested()
            // had nowhere to go, so the menu item did nothing. Same call
            // shape as PaneLeaf.qml's own tab-bar wiring
            // (`controller.closeTab(node.id, tabId)`); leafId here is
            // always root.node.id (see PaneLeaf.qml's own leafId
            // bindings), so it stands in for the areaId.
            onCloseRequested: {
                if (root.controller && root._activeTab)
                    root.controller.closeTab(root.leafId, root._activeTab.id);
            }
        },

        // The active view's own icon (from viewType, via
        // controller.iconRegistry), sitting just right of the grip --
        // Blender's editor areas show the same kind of editor-type icon at
        // the head of their header, and clicking it there pops up a list
        // to switch the area to a different editor type. Same here: this
        // is a ViewTypePickerButton over controller.viewTypeCategories --
        // it shows a *currently selected value* (the active view's icon)
        // plus a trailing chevron, unlike the plain action menus below
        // (HeaderMenuGroup), and its popup has a pinned search field so
        // typing filters straight to a matching entry (see
        // ViewTypePickerButton.qml's own class comment) -- and choosing an
        // entry swaps this pane's view type in place via
        // controller.changePaneType().
        ViewTypePickerButton {
            id: typeButton
            height: root.contentHeight
            visible: root._activeTab !== null && (root.controller ? (root.controller.viewTypeRegistry || []).length > 0 : false)
            iconName: root._activeIcon
            categories: root.controller ? root.controller.viewTypeCategories : []
            selectedViewType: root._activeTab ? root._activeTab.viewType : ""

            onViewTypeSelected: (viewType, title) => {
                if (root._activeTab)
                    root.controller.changePaneType(root._activeTab.id, viewType, title);
            }

            // Same three hookups HeaderMenuGroup.qml's own buttons make
            // to _menuCoordinator -- see that property's comment above.
            onOpened: root._menuCoordinator.noteOpened(typeButton)
            onClosed: root._menuCoordinator.noteClosed(typeButton)
            onHoveredChanged: {
                if (typeButton.hovered)
                    root._menuCoordinator.noteHovered(typeButton);
            }
        },

        // See this file's class comment for what paneHeaderModeSwitch is
        // -- its items land in this plain Row, right after the pane-type
        // switcher and before the menu buttons. `data:` is a single,
        // ordinary list<QtObject> assignment (empty when a view supplies
        // none, collapsing this Row to zero width) -- the same proven
        // shape `center:`/`end:` already use for paneHeaderCenter/
        // paneHeaderEnd below, deliberately not a JS array splice/concat
        // into `start` itself (that shape previously made the whole
        // `start` row -- grip and typeButton included -- vanish at
        // runtime despite compiling cleanly).
        Row {
            id: modeSwitchSlot
            spacing: Units.smallSpacing
            data: root._modeSwitchItems
        },
        HeaderMenuGroup {
            menus: root._effectiveMenus
            buttonHeight: root.contentHeight
            availableWidth: root._menuGroupAvailableWidth
            coordinator: root._menuCoordinator
        }
    ]

    // Active-pane accent line -- see _active's own comment above. Same
    // highlightColor accent PaneTabHeader.qml already uses for the
    // active tab, at the bottom edge (matching that tab-strip line's own
    // position at the top of the row directly below).
    Rectangle {
        id: activeAccent

        // Inset from both edges rather than spanning the full width:
        // this header's own background (MultiRowHeaderBar.qml) draws with
        // Units.cornerRadius, which a corner-radius preset (esp.
        // "circle", an intentionally oversized constant -- see
        // Units.qml's _cornerRadiusPresets comment) can round well past
        // a plain visual nicety and into "this line visibly runs past
        // the rounded corner" territory. Math.min(..., root.height / 2)
        // mirrors Rectangle's own automatic radius clamping (a radius
        // can never exceed half the shorter side), so this tracks
        // whatever the corner actually renders at, not the raw
        // (possibly huge) preset value -- plus a bit of breathing room
        // past the tangent point rather than touching it exactly.
        readonly property real _inset: Math.min(Units.cornerRadius, root.height / 2) + Units.smallSpacing

        // Width-only Behavior (not a generic 幅+visible fade): grows
        // from/shrinks to a centered point, per request ("中心から伸びる
        // みたいなアニメーション") -- anchoring to horizontalCenter rather
        // than left/right means animating width alone already reads as
        // "growing outward from the middle" with no extra x bookkeeping.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: 1
        width: root._active ? Math.max(0, parent.width - activeAccent._inset * 2) : 0

        // Fades to transparent at both ends rather than a flat color --
        // Gradient.Horizontal (not the default vertical) so the fade
        // runs along the line's length.
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.colors.highlightColor.r, root.colors.highlightColor.g, root.colors.highlightColor.b, 0)
            }
            GradientStop {
                position: 0.5
                color: root.colors.highlightColor
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root.colors.highlightColor.r, root.colors.highlightColor.g, root.colors.highlightColor.b, 0)
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
