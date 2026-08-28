import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Renders a "drawer" node (see PaneView.qml's class comment): a fixed-
// size rail of icon-only tab buttons -- either a vertical column pinned
// to the left edge, or a horizontal row pinned to the top edge (see
// `effectiveOrientation` below) -- plus, expanded, the active child's
// content filling the remaining space beside/below it. Either way the
// rail sits at the same position/size whether expanded or collapsed --
// only whether the active tab's content shows beside/below it changes
// between those two states.
//
// Orientation: normally a manual per-drawer toggle, via an item in the
// rail's own hamburger menu ("横向きレールに切替"/"縦向きレールに切替"),
// persisted as `node.orientation`. EXCEPTION: a drawer that's a direct
// child of a "split" node instead has its orientation *forced*, via
// `splitOrientation` below (set by PaneNode.qml's own passthrough -- see
// PaneSplit.qml's Repeater delegate), to whichever rail shape keeps the
// collapsed rail's fixed dimension aligned with that split's own resize
// axis: a horizontal split (side-by-side cells, resized along width)
// forces a vertical/fixed-width rail, a vertical split (stacked cells,
// resized along height) forces a horizontal/fixed-height rail -- see
// PaneSplit.qml's fixedSizes comment for why that pairing matters.
// The manual hamburger menu item is disabled in that case (same
// enabled-false-while-static-text idiom `_groupMenuItems`'s own "タブに
// 変更" entry already uses for canConvertDrawerToTabs).
//
// Expanded, the active child's content fills the remaining width/height
// beside/below the rail, and clicking a tab switches which child shows
// there inline. Collapsed, that content area is hidden entirely (only
// the rail remains) and clicking a tab instead shows that child's
// content in a floating overlay (overlayPopup below, modeled on
// CollapsibleTextField.qml's own collapsedPopup) positioned in that same
// spot beside/below the rail, rather than switching inline -- there's no
// visible content area to switch into while collapsed.
//
// The body itself (bodyArea) renders every child through its own generic
// recursive PaneNode (only the active one visible) rather than
// PaneLeaf's bare-pane-only materialize/reparent logic: unlike "tabs", a
// drawer's children aren't restricted to bare panes -- dropping a pane
// onto an existing "tabs" group's own drawer-top/drawer-bottom edge (see
// PaneDropOverlay.qml) nests that whole group as one drawer child, same
// as the old "stack" allowed.
//
// The rail reuses PaneTabHeader.qml (the same component the horizontal
// "tabs" strip uses) with `iconOnly: true`. The vertical and horizontal
// rail blocks below are two separate Column/Row instances (rather than
// one generic positioner switching axis) because each only manages the
// one axis it's named after, leaving the other free for each child's own
// centering anchor (`anchors.horizontalCenter`/`verticalCenter`) --
// `Flow` (the obvious single-positioner alternative) manages *both*
// axes, which conflicts with anchors on its children.
Item {
    id: root
    property var node
    property var controller

    // Whether this drawer's own "group frame" (margin + border around
    // the body, rail excluded) should be drawn. Set by the caller,
    // PaneNode.qml: see its comment for why that decision lives there
    // rather than being a node.type check here.
    property bool framed: false

    property bool expanded: true

    // Fixed size of this drawer cell along its parent split's axis, in px,
    // or 0 when expanded (proportional share, same as an ordinary pane).
    // Read by PaneNode.qml and forwarded to PaneSplit.qml.
    //
    // Collapsed → occupies exactly `railSize` px (the icon-only rail that
    // stays visible). Expanded → 0, meaning PaneSplit gives this cell its
    // usual proportional share from `node.children[i].size`.
    //
    // Because this is a real QML property with change notification,
    // PaneSplit.qml's `onFixedSizePxChanged` handler fires automatically
    // whenever the drawer is toggled, with no extra wiring needed.
    readonly property real fixedSizePx: root.expanded ? 0 : root.railSize

    // Set by PaneNode.qml's passthrough (see PaneSplit.qml's Repeater
    // delegate) to the enclosing split's own orientation, or "" if this
    // drawer isn't a direct split child. See this file's class comment.
    property string splitOrientation: ""

    // Local mirror of node.orientation, same pattern (and reason) as
    // `expanded`/`currentIndex` below: node.orientation is a plain JS
    // field controller.setDrawerOrientation() mutates in place, which
    // fires no QML change notification. Only actually used when
    // splitOrientation is "" -- see effectiveOrientation below.
    property string _manualOrientation: "vertical"

    // Local mirrors of node.overlayWidth/node.overlayHeight, same pattern
    // (and reason) as `_manualOrientation` above: these are plain JS
    // fields mutated in place by controller.setDrawerOverlayWidth()/
    // setDrawerOverlayHeight() (see overlayPopup's own comment below),
    // which fires no QML change notification. Fall back to the same
    // pixel defaults the overlay used before these became resizable/
    // persisted when the node has never been resized (field absent).
    property real _overlayWidth: StyleKit.Units.gridUnit * 30
    property real _overlayHeight: StyleKit.Units.gridUnit * 24

    function _setOverlayWidth(width) {
        root._overlayWidth = width;
        if (root.controller && root.node)
            root.controller.setDrawerOverlayWidth(root.node.id, width);
    }

    function _setOverlayHeight(height) {
        root._overlayHeight = height;
        if (root.controller && root.node)
            root.controller.setDrawerOverlayHeight(root.node.id, height);
    }

    // The rail orientation actually in effect: forced by the enclosing
    // split if there is one (splitOrientation !== ""), otherwise the
    // manually-toggled/persisted one.
    readonly property string effectiveOrientation: root.splitOrientation === "horizontal" ? "vertical" : root.splitOrientation === "vertical" ? "horizontal" : root._manualOrientation
    readonly property bool horizontal: root.effectiveOrientation === "horizontal"

    // Local mirror of node.currentIndex, same pattern (and same reason)
    // as PaneLeaf.qml's own `currentIndex`: node.currentIndex is a plain
    // JS field controller.setCurrentTab() mutates in place (see its own
    // comment), which fires no QML change notification -- a binding
    // reading node.currentIndex directly (as this used to) would never
    // re-evaluate after a tab click, so the active highlight and the
    // body content would silently stay stuck on the old tab. Set
    // explicitly, immediately, in _selectTab() below.
    property int currentIndex: 0

    function _refresh() {
        root.expanded = !root.node || root.node.expanded !== false;
        root.currentIndex = (root.node && root.node.currentIndex < root.node.children.length) ? root.node.currentIndex : 0;
        root._manualOrientation = (root.node && root.node.orientation === "horizontal") ? "horizontal" : "vertical";
        root._overlayWidth = (root.node && root.node.overlayWidth > 0) ? root.node.overlayWidth : StyleKit.Units.gridUnit * 30;
        root._overlayHeight = (root.node && root.node.overlayHeight > 0) ? root.node.overlayHeight : StyleKit.Units.gridUnit * 24;
    }

    onNodeChanged: root._refresh()
    Component.onCompleted: root._refresh()

    function _toggle() {
        root.expanded = !root.expanded;
        if (root.controller && root.node)
            root.controller.setDrawerExpanded(root.node.id, root.expanded);
    }

    function _toggleOrientation() {
        var next = root.horizontal ? "vertical" : "horizontal";
        root._manualOrientation = next;
        if (root.controller && root.node)
            root.controller.setDrawerOrientation(root.node.id, next);
    }

    // Same constant PaneSplit.qml shrinks a collapsed cell's fixed
    // dimension to when this drawer is nested in a split -- see
    // PaneSplit.qml's fixedSizes comment. Used as the rail's width
    // when vertical, height when horizontal.
    readonly property real railSize: StyleKit.Units.collapsedDrawerSize

    // Floor for overlayPopup's resizable dimension (see its own comment
    // below) -- keeps a careless drag from shrinking it down to
    // uselessness.
    readonly property real _overlayMinSize: StyleKit.Units.gridUnit * 10

    readonly property var bodyColors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // A drawer child isn't necessarily a bare "pane" (see this file's
    // class comment), so a nested split/tabs/drawer child has neither a
    // `title` nor a `viewType` of its own -- title falls back to blank
    // for that case rather than guessing, same tolerance the old
    // PaneStack.qml's collapsedIcons column already had for exactly this
    // situation.
    function _tabTitle(childNode) {
        return childNode ? (childNode.title || "") : "";
    }

    // Icon(s) for one rail tab, passed to PaneTabHeader's iconNames (see
    // its own comment): a bare pane contributes its own single icon; a
    // nested group child (split/tabs/drawer -- see this file's class
    // comment) recurses into every member instead of falling back to a
    // blank icon, so PaneTabHeader can render the group as a composite
    // IconStack rather than an unlabeled tab. Depth-first, so a group
    // nested inside a group still contributes every leaf pane's icon.
    function _tabIcons(childNode) {
        if (!childNode || !root.controller || !root.controller.iconRegistry)
            return [];
        if (childNode.type === "pane") {
            var icon = root.controller.iconRegistry[childNode.viewType || ""] || "";
            return icon ? [icon] : [];
        }
        var icons = [];
        var members = childNode.children || [];
        for (var i = 0; i < members.length; i++) {
            icons = icons.concat(root._tabIcons(members[i].node));
        }
        return icons;
    }

    function _selectTab(index) {
        if (!root.node)
            return;
        // Collapsed and re-clicking the same tab that's already showing
        // in the overlay: toggle it closed instead of just re-opening
        // the same content. Doesn't touch currentIndex/the controller --
        // closing the overlay was never supposed to change tab selection
        // (see _overlayIndex's own comment below).
        if (!root.expanded && root._overlayIndex === index) {
            overlayPopup.close();
            return;
        }
        if (root.controller && root.node.id !== undefined)
            root.controller.setCurrentTab(root.node.id, index);
        root.currentIndex = index;
        if (!root.expanded)
            root._openOverlay(index);
    }

    // Which child the collapsed overlay is currently showing (-1 =
    // closed). Kept separate from node.currentIndex: opening the overlay
    // for a tab also updates currentIndex (so that tab stays selected if
    // the drawer is later expanded, via _selectTab above), but closing
    // the overlay shouldn't itself change which tab is selected.
    property int _overlayIndex: -1

    function _openOverlay(index) {
        root._overlayIndex = index;
        overlayPopup._flip = root._overlayWouldOverflow();
        overlayPopup.open();
    }

    // Whether opening overlayPopup the usual way (see its own class
    // comment) would run it past the edge of the window this drawer is
    // actually shown in right now -- e.g. this drawer is the
    // rightmost/bottommost cell of a split, flush against that edge.
    // Measured fresh (via mapToItem, not a stored binding -- see
    // overlayPopup._flip's own comment for why) each time this is
    // called, so a drawer that's been dragged/resized since the last
    // open() is checked against where it actually is now.
    function _overlayWouldOverflow() {
        var win = root.Window.window;
        if (!win)
            return false;
        var pos = root.mapToItem(win.contentItem, 0, 0);
        if (root.horizontal)
            return pos.y + root.railSize + StyleKit.Units.largeSpacing + root._overlayHeight > win.height;
        return pos.x + root.railSize + StyleKit.Units.largeSpacing + root._overlayWidth > win.width;
    }

    readonly property var _groupMenuItems: [
        {
            text: "タブに変更",
            enabled: (root.controller && root.node) ? root.controller.canConvertDrawerToTabs(root.node.id) : false,
            onTriggered: function () {
                if (root.controller && root.node)
                    root.controller.setGroupType(root.node.id, "tabs");
            }
        },
        {
            // Disabled while a "split" parent forces this drawer's
            // orientation instead -- see this file's class comment.
            text: root.horizontal ? "縦向きレールに切替" : "横向きレールに切替",
            enabled: root.splitOrientation === "",
            onTriggered: function () {
                root._toggleOrientation();
            }
        },
        {
            text: "すべてのタブを閉じる",
            enabled: (root.node && root.node.children) ? root.node.children.length > 0 : false,
            // Deferred via Qt.callLater -- see PaneTabBar.qml's identical
            // hamburger item for why: this can destroy this very
            // HamburgerButton/ThemedMenu's own hosting PaneDrawer as a
            // side effect (emptying the group rebuilds root.tree, which
            // this same array's own bindings read through root.node),
            // and doing that synchronously from inside the menu's own
            // onTriggered crashed live ("Value is undefined and could
            // not be converted to an object").
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
            text: "ドロワーを閉じる",
            // See "すべてのタブを閉じる" above for why this is deferred.
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

    // Base fill for the whole drawer, root-level rather than scoped to
    // rail/bodyArea individually -- same reasoning as the old
    // PaneStack.qml's own base Rectangle. Same opaque-unless-a-background-
    // image-is-set behavior as PaneLeaf.qml's own pane background (see its
    // comment) -- fully opaque here until the user actually picks one.
    Rectangle {
        anchors.fill: parent
        color: Origami.PaneBackdrop.imagePath.length > 0 ? Qt.rgba(root.bodyColors.backgroundColor.r, root.bodyColors.backgroundColor.g, root.bodyColors.backgroundColor.b, Origami.PaneBackdrop.paneOpacity) : root.bodyColors.backgroundColor
    }

    // Rail -- vertical variant: fixed-width column pinned to the left
    // edge, spanning the full height (see this file's class comment for
    // why this and railHorizontal below are two separate blocks rather
    // than one orientation-switching positioner).
    Column {
        id: railVertical
        visible: !root.horizontal
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.railSize
        spacing: StyleKit.Units.smallSpacing

        // Grab handle for dragging/moving this entire drawer node
        Origami.PaneGrip {
            id: drawerGripV
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontal: true
            visible: !(root.controller && root.controller.layoutLocked)
            title: root.node ? (root.node.title || "ドロワー") : ""
            tabId: root.node ? root.node.id : -1
            leafId: root.node ? root.node.id : -1
            controller: root.controller
        }

        Origami.ToggleButton {
            anchors.horizontalCenter: parent.horizontalCenter
            iconName: root.expanded ? "chevron-down" : "chevron-right"
            checked: root.expanded
            onToggled: root._toggle()
        }

        Origami.HamburgerButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.railSize
            height: root.railSize
            iconName: "application-menu-symbolic"
            menuItems: root._groupMenuItems
        }

        // model is emptied out (rather than just relying on railVertical's
        // own `visible: !root.horizontal` above) whenever the horizontal
        // rail is the one actually in effect -- otherwise this Repeater
        // built a full PaneTabHeader per drawer child regardless of which
        // rail was shown (`visible: false` hides a Repeater's delegates,
        // it doesn't stop it building them), doubling the rail-tab item
        // count for every drawer node in the tree. See railHorizontal's
        // own Repeater below for the mirror image of this.
        Repeater {
            model: root.horizontal ? [] : (root.node ? root.node.children : [])

            delegate: Origami.PaneTabHeader {
                id: railTabV
                required property var modelData
                required property int index

                anchors.horizontalCenter: parent.horizontalCenter
                title: root._tabTitle(railTabV.modelData.node)
                tabId: railTabV.modelData.node.id
                leafId: root.node ? root.node.id : -1
                active: railTabV.index === root.currentIndex
                controller: root.controller
                iconNames: root._tabIcons(railTabV.modelData.node)
                iconStackOrientation: "vertical"
                iconOnly: true
                activeEdge: "right"
                onClicked: root._selectTab(railTabV.index)
                onCloseRequested: {
                    if (root.controller && root.node)
                        root.controller.closeTab(root.node.id, railTabV.tabId);
                }
            }
        }
    }

    DropArea {
        id: railDropV
        visible: !root.horizontal
        anchors.fill: railVertical
        keys: ["pane-tab"]
        z: 50

        property int targetIndex: -1
        property real lineY: -1

        function updateIndex(drag) {
            if (!root.node || !root.node.children)
                return;
            var dragSource = drag.source;
            if (!dragSource)
                return;

            var localPos = railDropV.mapFromItem(root, drag.x, drag.y);
            var bestIdx = 0;
            var bestY = 0;
            var children = root.node.children || [];
            var count = children.length;

            var found = false;
            for (var i = 0; i < count; i++) {
                var tabItem = railVertical.children[i + 3];
                if (!tabItem || !tabItem.mapToItem)
                    continue;
                var tabPos = tabItem.mapToItem(railDropV, 0, 0);
                var midY = tabPos.y + tabItem.height / 2;
                if (localPos.y < midY) {
                    bestIdx = i;
                    bestY = tabPos.y;
                    found = true;
                    break;
                }
            }
            if (!found && count > 0) {
                var lastItem = railVertical.children[count + 2];
                if (lastItem && lastItem.mapToItem) {
                    var lastPos = lastItem.mapToItem(railDropV, 0, 0);
                    bestIdx = count;
                    bestY = lastPos.y + lastItem.height;
                }
            }

            railDropV.targetIndex = bestIdx;
            railDropV.lineY = bestY;

            dragSource.hoverController = root.controller;
            dragSource.hoverLeafId = root.node ? root.node.id : -1;
            dragSource.hoverZone = "header";
            dragSource.hoverTargetIndex = bestIdx;
        }

        onPositionChanged: drag => {
            drag.accept();
            railDropV.updateIndex(drag);
        }
        onEntered: drag => {
            drag.accept();
            railDropV.updateIndex(drag);
        }
        onExited: {
            railDropV.targetIndex = -1;
            railDropV.lineY = -1;
            if (railDropV.dragSource) {
                railDropV.dragSource.hoverTargetIndex = -1;
            }
        }

        Rectangle {
            visible: railDropV.containsDrag && railDropV.lineY >= 0
            y: railDropV.lineY - 1.5
            x: 2
            height: 3
            width: parent.width - 4
            color: StyleKit.Theme.paletteFor(StyleKit.Theme.header).positiveTextColor
            z: 100
        }
    }

    // Rail -- horizontal variant: same content as railVertical above,
    // just fixed-height and pinned to the top edge, spanning the full
    // width.
    Row {
        id: railHorizontal
        visible: root.horizontal
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.railSize
        spacing: StyleKit.Units.smallSpacing

        // Grab handle for dragging/moving this entire drawer node
        Origami.PaneGrip {
            id: drawerGripH
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            horizontal: false
            visible: !(root.controller && root.controller.layoutLocked)
            title: root.node ? (root.node.title || "ドロワー") : ""
            tabId: root.node ? root.node.id : -1
            leafId: root.node ? root.node.id : -1
            controller: root.controller
        }

        Origami.ToggleButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: root.expanded ? "chevron-down" : "chevron-right"
            checked: root.expanded
            onToggled: root._toggle()
        }

        Origami.HamburgerButton {
            anchors.verticalCenter: parent.verticalCenter
            width: root.railSize
            height: root.railSize
            iconName: "application-menu-symbolic"
            menuItems: root._groupMenuItems
        }

        // Mirror of railVertical's own Repeater above -- see its comment.
        Repeater {
            model: root.horizontal ? (root.node ? root.node.children : []) : []

            delegate: Origami.PaneTabHeader {
                id: railTabH
                required property var modelData
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                title: root._tabTitle(railTabH.modelData.node)
                tabId: railTabH.modelData.node.id
                leafId: root.node ? root.node.id : -1
                active: railTabH.index === root.currentIndex
                controller: root.controller
                iconNames: root._tabIcons(railTabH.modelData.node)
                iconStackOrientation: "horizontal"
                iconOnly: true
                activeEdge: "bottom"
                onClicked: root._selectTab(railTabH.index)
                onCloseRequested: {
                    if (root.controller && root.node)
                        root.controller.closeTab(root.node.id, railTabH.tabId);
                }
            }
        }
    }

    DropArea {
        id: railDropH
        visible: root.horizontal
        anchors.fill: railHorizontal
        keys: ["pane-tab"]
        z: 50

        property int targetIndex: -1
        property real lineX: -1

        function updateIndex(drag) {
            if (!root.node || !root.node.children)
                return;
            var dragSource = drag.source;
            if (!dragSource)
                return;

            var localPos = railDropH.mapFromItem(root, drag.x, drag.y);
            var bestIdx = 0;
            var bestX = 0;
            var children = root.node.children || [];
            var count = children.length;

            var found = false;
            for (var i = 0; i < count; i++) {
                var tabItem = railHorizontal.children[i + 3];
                if (!tabItem || !tabItem.mapToItem)
                    continue;
                var tabPos = tabItem.mapToItem(railDropH, 0, 0);
                var midX = tabPos.x + tabItem.width / 2;
                if (localPos.x < midX) {
                    bestIdx = i;
                    bestX = tabPos.x;
                    found = true;
                    break;
                }
            }
            if (!found && count > 0) {
                var lastItem = railHorizontal.children[count + 2];
                if (lastItem && lastItem.mapToItem) {
                    var lastPos = lastItem.mapToItem(railDropH, 0, 0);
                    bestIdx = count;
                    bestX = lastPos.x + lastItem.width;
                }
            }

            railDropH.targetIndex = bestIdx;
            railDropH.lineX = bestX;

            dragSource.hoverController = root.controller;
            dragSource.hoverLeafId = root.node ? root.node.id : -1;
            dragSource.hoverZone = "header";
            dragSource.hoverTargetIndex = bestIdx;
        }

        onPositionChanged: drag => {
            drag.accept();
            railDropH.updateIndex(drag);
        }
        onEntered: drag => {
            drag.accept();
            railDropH.updateIndex(drag);
        }
        onExited: {
            railDropH.targetIndex = -1;
            railDropH.lineX = -1;
            if (railDropH.dragSource) {
                railDropH.dragSource.hoverTargetIndex = -1;
            }
        }

        Rectangle {
            visible: railDropH.containsDrag && railDropH.lineX >= 0
            x: railDropH.lineX - 1.5
            y: 2
            width: 3
            height: parent.height - 4
            color: StyleKit.Theme.paletteFor(StyleKit.Theme.header).positiveTextColor
            z: 100
        }
    }

    // Body: beside the vertical rail or below the horizontal one, only
    // shown while expanded -- collapsed, the active child's content is
    // only reachable via overlayPopup below. Framed (margin + border) as
    // one unit, same as PaneLeaf.qml frames its header+content but
    // excludes its tab strip -- here it's the rail that stays outside
    // the frame instead. No margin on the rail-adjacent edge: the rail
    // already provides the visual gap there, so adding one too would
    // double it up.
    Item {
        id: bodyArea

        // Fades in/out on expand/collapse, faster than overlayPopup's own
        // enter/exit Transition further down since this fade runs
        // alongside the rail-adjacent PaneSplit geometry animation (see
        // PaneSplit.qml's own per-cell Behaviors) rather than standing
        // alone, so it needs to keep pace with that resize instead of
        // lagging behind it. Stays visible (and its Repeater's model
        // below stays populated) for the duration of the fade-out --
        // root.expanded flipping straight to false would otherwise tear
        // down every child PaneNode before the animation had a chance to
        // play, leaving an empty box to fade rather than the actual
        // content (same reasoning as overlayPopup's own onClosed comment
        // below).
        readonly property bool _visuallyExpanded: root.expanded || bodyArea.opacity > 0
        visible: bodyArea._visuallyExpanded
        opacity: root.expanded ? 1.0 : 0.0
        clip: true

        Behavior on opacity {
            NumberAnimation {
                duration: StyleKit.Units.veryShortDuration
                easing.type: Easing.OutQuad
            }
        }

        anchors.left: root.horizontal ? parent.left : railVertical.right
        anchors.top: root.horizontal ? railHorizontal.bottom : parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: (root.framed && root.horizontal) ? StyleKit.Units.groupContentMargin : 0
        anchors.topMargin: (root.framed && !root.horizontal) ? StyleKit.Units.groupContentMargin : 0
        anchors.rightMargin: root.framed ? StyleKit.Units.groupContentMargin : 0
        anchors.bottomMargin: root.framed ? StyleKit.Units.groupContentMargin : 0

        // One PaneNode per child, kept alive the whole time bodyArea is
        // shown (not swapped in place) -- only the current one is
        // `visible`. A single PaneNode whose `node` binding was swapped
        // between children used to be the approach here, but a bare
        // "pane" child reuses the very same PaneLeaf instance across
        // that swap (PaneNode.qml's Loader only recreates on a node.type
        // change, and "pane" -> "pane" isn't one) -- PaneLeaf's own
        // materialize/show logic only ever hides siblings it knows about
        // from the *current* node's own children (see its
        // _updateContent()'s comment), so the *previous* child's item
        // was left reparented and visible, silently piling up behind
        // whichever child got shown next. Each child owning its own
        // stable PaneNode instead means switching tabs is a plain
        // visibility toggle, the same pattern PaneLeaf.qml itself uses
        // for an actual "tabs" node's alternate children.
        Repeater {
            model: bodyArea._visuallyExpanded && root.node ? root.node.children : []

            delegate: Origami.PaneNode {
                id: cell
                required property var modelData
                required property int index

                anchors.fill: parent
                visible: cell.index === root.currentIndex
                // Defers each child's own materialize() cost until it's
                // actually the selected tab -- see PaneLeaf.qml's
                // `active` property comment for the full reasoning.
                // `visible` above already hides every non-current
                // child's Item; this additionally stops non-current
                // children from ever building their content in the
                // first place until first selected.
                active: cell.index === root.currentIndex
                node: cell.modelData.node
                controller: root.controller
                // The body sits inside this drawer's own frame region
                // (or an ancestor's, if this drawer's own frame was
                // itself suppressed -- see PaneNode.qml's comment);
                // unconditionally suppress a further nested frame here
                // either way.
                ancestorFramed: true
                // Only the visible child's corners matter -- it's
                // simultaneously "first" and "last" among the ones
                // actually shown, so all four match the group frame's
                // own radius, unlike the old PaneStack.qml's multi-child
                // bodyArea Repeater (which only rounded the first/last
                // child's outer corners).
                topLeftRadius: root.framed ? StyleKit.Units.cornerRadius : 0
                topRightRadius: root.framed ? StyleKit.Units.cornerRadius : 0
                bottomLeftRadius: root.framed ? StyleKit.Units.cornerRadius : 0
                bottomRightRadius: root.framed ? StyleKit.Units.cornerRadius : 0
            }
        }

        // A drawer is never auto-collapsed away just for running out of
        // tabs (see PaneView.qml's _isGroupType() comment) -- closing
        // its last tab leaves it sitting empty instead, so this says so
        // rather than just showing blank space.
        Origami.Label {
            anchors.centerIn: parent
            visible: root.node && root.node.children.length === 0
            type: "secondary"
            text: "タブがありません"
        }

        Rectangle {
            anchors.fill: parent
            z: 1
            visible: root.framed
            radius: StyleKit.Units.cornerRadius
            color: "transparent"
            border.width: StyleKit.Units.borderWidth
            border.color: root.bodyColors.borderColor
        }
    }

    // Collapsed-tab overlay -- modeled on CollapsibleTextField.qml's own
    // collapsedPopup: parented to root (rather than the default) with
    // CloseOnPressOutsideParent so it doesn't fight whichever tab
    // button's own click just opened it, and closes on Escape too.
    // Positioned in the same spot bodyArea would occupy if expanded --
    // beside the vertical rail, or below the horizontal one (which stays
    // in the same place either way -- see this file's class comment) --
    // unless that would run the popup past the window's own edge (e.g.
    // this drawer is the rightmost/bottommost cell of a split, flush
    // against it), in which case it opens the other way instead -- see
    // _flip below.
    //
    // Sized asymmetrically along the two axes: the dimension that lines
    // up with the rail's own fixed axis (height beside a vertical rail,
    // width below a horizontal one) is matched to the drawer's own full
    // size minus margin, same as bodyArea's own expanded sizing along
    // that axis; the other, "free" dimension (width/height respectively)
    // is a dedicated resizable+persisted property (root._overlayWidth/
    // _overlayHeight, dragged via the resize handle below) rather than
    // reusing bodyArea's own remaining-space sizing, since bodyArea has
    // no equivalent property to reuse (it just fills to parent.right/
    // bottom) and this overlay floats independently of that layout.
    //
    // `_margin` is applied on every side (not just the rail-adjacent
    // edge) so the overlay never sits flush against the drawer's own
    // bounds, corners included. `padding` is left at the themed Popup's
    // own default (see widgets/Popup.qml) rather than overridden to 0:
    // at 0, the content fills exactly to the background Rectangle's own
    // bounds and opaquely covers its themed border, making it invisible.
    QQC2.Popup {
        id: overlayPopup
        parent: root
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent

        // See widgets/Popup.qml's own detachedWindow comment: this is one
        // of the two call sites that actually need to draw past the app
        // window's own edge (a drawer near the edge of a split cell would
        // otherwise clip _overlayWidth/_overlayHeight below at that edge,
        // which is exactly what _overlayWouldOverflow()/_flip further down
        // hand-roll a workaround for). This overlay can host arbitrary
        // pane content (terminal, text editor, etc.) that needs real
        // keyboard input to work at all -- see that same comment for why
        // this depends on qtwayland actually being present at runtime.
        popupType: QQC2.Popup.Item

        readonly property real _margin: StyleKit.Units.largeSpacing

        // Whether expanding the usual way (right of a vertical rail,
        // below a horizontal one) would overshoot the window edge on
        // that axis -- flips the popup to the opposite side instead of
        // letting it hang off the window. Independent of which side
        // bodyArea itself expands to while expanded (see this Popup's
        // own class comment): that's fixed layout within root's own
        // bounds and never overflows a window edge the way this floating
        // overlay can.
        //
        // Set imperatively by root._openOverlay() right before open(),
        // rather than kept as a live binding on root's window position:
        // Item.mapToItem()'s result isn't tracked by QML's automatic
        // binding dependency analysis (it's a native call, not a plain
        // property read the engine can see into), so a binding built on
        // it would only ever reflect wherever this drawer was the moment
        // the binding first evaluated -- never anywhere it moves to
        // afterward (e.g. after a split resize). Recomputing at each
        // open() instead means it's always measured against root's
        // current position.
        property bool _flip: false

        x: root.horizontal ? overlayPopup._margin : (overlayPopup._flip ? -(root._overlayWidth + overlayPopup._margin) : root.railSize + overlayPopup._margin)
        y: root.horizontal ? (overlayPopup._flip ? -(root._overlayHeight + overlayPopup._margin) : root.railSize + overlayPopup._margin) : overlayPopup._margin
        width: root.horizontal ? root.width - overlayPopup._margin * 2 : root._overlayWidth
        height: root.horizontal ? root._overlayHeight : root.height - overlayPopup._margin * 2

        // Fade in/out on open/close -- same duration/easing convention as
        // every other animated show/hide in this codebase (e.g.
        // CollapsibleSection.qml's implicitHeight Behavior).
        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: StyleKit.Units.shortDuration
                easing.type: Easing.OutQuad
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: StyleKit.Units.shortDuration
                easing.type: Easing.InQuad
            }
        }

        // onClosed (fires once the exit Transition above has actually
        // finished), not onOpenedChanged (which fires the instant
        // close() is called, before that fade-out plays) -- otherwise
        // the content Repeater's `visible: index === root._overlayIndex`
        // bindings below would blank out immediately, leaving an empty
        // box to fade out rather than the actual content.
        onClosed: root._overlayIndex = -1

        // One PaneNode per child, same reasoning as bodyArea's own
        // Repeater above (a single swapped-`node` PaneNode here would
        // hit the identical stale-visible-sibling bug across repeated
        // opens for different tabs) -- only the one at _overlayIndex is
        // shown.
        contentItem: Item {
            Repeater {
                model: overlayPopup.opened && root.node ? root.node.children : []

                delegate: Origami.PaneNode {
                    id: overlayCell
                    required property var modelData
                    required property int index

                    anchors.fill: parent
                    visible: overlayCell.index === root._overlayIndex
                    // See bodyArea's own identical `active` binding
                    // above for the reasoning.
                    active: overlayCell.index === root._overlayIndex
                    node: overlayCell.modelData.node
                    controller: root.controller
                    ancestorFramed: true
                }
            }

            // Resize handle for the overlay's "free" dimension (see
            // overlayPopup's own comment above) -- normally the edge
            // furthest from the rail (right edge for a vertical rail,
            // drags width; bottom edge for a horizontal one, drags
            // height), so dragging away from the rail grows the overlay.
            // When overlayPopup._flip has swapped which side the overlay
            // opens on, "furthest from the rail" is the opposite edge
            // instead (left/top) -- this follows that flip so the handle
            // never ends up on the rail-adjacent edge, which would be
            // both visually wrong and impossible to grab (covered by the
            // rail itself). Same grabMargin-wider-than-the-visual-gap-
            // itself hit-area trick, and same drag-delta-via-a-stable-
            // coordinate-frame technique (here: root, which doesn't move
            // or resize as this drag proceeds), as PaneSplit.qml's own
            // drag handles.
            Item {
                id: overlayResizeHandle
                readonly property real grabMargin: StyleKit.Units.smallSpacing * 1.5

                // No anchors -- explicit x/y/width/height instead, same
                // as PaneSplit.qml's own handleArea, so the two branches
                // below don't fight over which anchors are set.
                x: root.horizontal ? 0 : (overlayPopup._flip ? 0 : parent.width - overlayResizeHandle.grabMargin)
                y: root.horizontal ? (overlayPopup._flip ? 0 : parent.height - overlayResizeHandle.grabMargin) : 0
                width: root.horizontal ? parent.width : overlayResizeHandle.grabMargin * 2
                height: root.horizontal ? overlayResizeHandle.grabMargin * 2 : parent.height

                MouseArea {
                    anchors.fill: parent
                    enabled: !(root.controller && root.controller.resizeLocked)
                    cursorShape: (root.controller && root.controller.resizeLocked) ? Qt.ArrowCursor : (root.horizontal ? Qt.SplitVCursor : Qt.SplitHCursor)
                    hoverEnabled: false

                    property real startPos: 0
                    property real startSize: 0

                    onPressed: mouse => {
                        var p = overlayResizeHandle.mapToItem(root, mouse.x, mouse.y);
                        startPos = root.horizontal ? p.y : p.x;
                        startSize = root.horizontal ? root._overlayHeight : root._overlayWidth;
                    }

                    onPositionChanged: mouse => {
                        if (!pressed)
                            return;
                        var p = overlayResizeHandle.mapToItem(root, mouse.x, mouse.y);
                        var cur = root.horizontal ? p.y : p.x;
                        // Flipped, this edge sits on the near side of the
                        // overlay instead of the far side (see this
                        // Item's own comment above), so growing the
                        // overlay means dragging toward the rail instead
                        // of away from it -- the delta's sign flips to
                        // match.
                        var delta = overlayPopup._flip ? -(cur - startPos) : (cur - startPos);
                        var next = Math.max(root._overlayMinSize, startSize + delta);
                        if (root.horizontal)
                            root._setOverlayHeight(next);
                        else
                            root._setOverlayWidth(next);
                    }
                }
            }
        }
    }
}
