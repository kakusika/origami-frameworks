import QtQuick
import QtQuick.Effects
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// An in-app "MDI-style" floating panel: draggable by its title bar,
// resizable from any edge/corner, brought to front on press -- lives
// inside the app's own window rather than a real OS-level one (see
// pane/window/PaneWindow.qml for that separate, existing mechanism).
//
// Can be declared as a plain child anywhere in the tree (like
// RenameDialog.qml is), or created dynamically via
// FloatingWindowRegistry.open(component, props) -- both paths converge on
// the same Component.onCompleted registration below, which is what
// reparents this into the shared FloatingWindowHost, so declaration site
// never matters for where it visually ends up.
//
// Three ways to populate the body, same split PaneWindow.qml uses for the
// same reason: `content` (the default property) for content declared
// statically in QML, `windowComponent` for a Component reference only
// available at call time (e.g. main.qml's ViewRegistry.componentRegistry
// entries) that needs createObject()'d fresh on open, or `hostedItem` for
// an already-live Item this window should adopt rather than create
// (PaneWindow.qml's own `hostedItem`/`paneComponent` split, mirrored).
//
// Also doubles as a one-pane "controller" from a real Origami.PaneHeader's
// point of view (paneHeader below, wired with node/controller/leafId) --
// this is what gives a floating pane the exact same header a docked one
// gets: drag grip, view-type switcher, its own paneHeaderMenus/Center/End/
// ModeSwitch, all for free, none of it reimplemented here. `node` is a
// synthetic single-"pane" tree (_paneNode below) rather than a real
// PaneView's tree; `iconRegistry`/`viewTypeRegistry`/`viewTypeCategories`/
// `componentRegistry` are borrowed from whatever real controller
// Origami.PaneContext.controller currently points at (the app's one real
// PaneView -- see main.qml), so the type switcher offers the exact same
// set of view types a docked pane would. Dragging paneHeader's own grip
// past its threshold and releasing over a real PaneView's leaf lets
// PaneGrip's existing cross-controller dispatch (see its class comment)
// turn this window's content into a real docked pane tab, via
// extractTab()/beginDrag()/endDrag()/dragLayer below -- this is never a
// real PaneView, and never a *target* for a drop (no insertTab()/
// insertTabAtIndex()), only ever a drag source.
//
// The window-chrome titlebar (title/minimize/maximize/close) is a
// separate row, FloatingWindowHeader.qml -- see that file's own class
// comment for why the two are kept apart rather than one hybrid header.
Item {
    id: root

    width: StyleKit.Units.gridUnit * 30
    height: StyleKit.Units.gridUnit * 20

    property string title: ""
    property bool closable: true
    property bool resizable: true
    property real minimumWidth: StyleKit.Units.gridUnit * 10
    property real minimumHeight: StyleKit.Units.gridUnit * 6

    // Whether paneHeader's own grip is shown at all, and whether it
    // responds to drag -- read by PaneHeader.qml itself via
    // `controller.layoutLocked` (see its own grip-visibility gate), no
    // wiring needed here beyond exposing this property. Not derived from
    // any specific PaneView (this window has no inherent dependency on
    // one) -- a caller that cares binds it explicitly, e.g.
    // `layoutLocked: mainPaneView.layoutLocked`.
    property bool layoutLocked: false

    // Window-chrome state -- see toggleMinimize()/toggleMaximize() below.
    property bool minimized: false
    property bool maximized: false
    property real _restoreHeight: 0
    property rect _restoreGeometry: Qt.rect(0, 0, 0, 0)

    // Interface parity with PaneView.dragActive -- nothing here reads it,
    // kept only because it's part of the same shape.
    property bool dragActive: false

    // Set once by Component.onCompleted below; not meant to be written by
    // callers, just readable so a caller holding this instance can pass
    // its id on to e.g. FloatingWindowRegistry.close()/bringToFront()
    // without keeping the whole component reference around.
    property int floatingWindowId: -1

    default property alias content: contentArea.data

    // See this file's class comment -- an alternative to `content` for a
    // Component only available at call time. Ignored if left null (the
    // ordinary `content` case).
    property Component windowComponent: null

    // A third way to populate the body, alongside `content`/`windowComponent`
    // above: an already-materialized, still-live Item (e.g. a docked pane's
    // own view, detached via controller.detachPane() -- see PaneHeader.qml's
    // "フローティングウィンドウに移動") that this window should adopt rather
    // than create fresh. Mirrors PaneWindow.qml's own `hostedItem` for the
    // same reason: the caller is expected to have already removed it from
    // wherever it used to live before this window becomes its new parent.
    // Ignored if left null. Checked before windowComponent in
    // Component.onCompleted below (mutually exclusive in practice -- a
    // caller sets one or the other, never both).
    property Item hostedItem: null

    // Optional, paired with windowComponent: a real viewType string (e.g.
    // a caller's own ViewRegistry.types.* entry) makes extractTab() below
    // return a fully persistence-capable tab (real component+viewType, so
    // it survives a workspace-tree save/reload same as any other pane).
    // Left empty -- including whenever content came in via plain `content`
    // children rather than windowComponent, which has no Component object
    // to hand back at all -- extractTab() still works, just produces an
    // item-only tab that a save/reload can't reconstruct (same graceful
    // drop an unknown viewType already gets elsewhere). Also gates whether
    // FloatingWindowRegistry.serializeWindows() includes this window at
    // all -- see its own comment.
    property string windowViewType: ""

    // Optional, paired with windowComponent: a previously-saved props bag
    // (FloatingWindowRegistry.restoreWindows()' own `entry.props`) applied
    // to the freshly created item via its optional paneRestore(props) --
    // same shape/optional-interface PaneView.qml's own materialize() uses
    // for a docked pane's saved state (e.g. GraphView.qml's collapsible-
    // panel open/closed state). Ignored if left null, or if the created
    // item doesn't implement paneRestore.
    property var restoreProps: null

    signal closeRequested

    function close() {
        root.closeRequested();
        Origami.FloatingWindowRegistry.close(root.floatingWindowId);
    }

    function bringToFront() {
        Origami.FloatingWindowRegistry.bringToFront(root.floatingWindowId);
    }

    // Keeps this window's top-left corner within the host's current
    // bounds, clamped to [0, host.size - this.size] -- degrades to pinning
    // at (0, 0) if this window is itself bigger than the host. x/y are
    // absolute and otherwise only ever touched by the titlebar drag/
    // resize-handle MouseAreas below. Used both as _scaleToHost()'s own
    // final safety step (rounding/the minimumWidth/minimumHeight floor can
    // still push a corner outside the host despite scaling) and after
    // toggleMaximize()'s own un-maximize restore (the saved geometry was
    // valid before maximizing but may no longer fit if the host shrank
    // while maximized).
    function _clampPosition() {
        var host = root.parent;
        if (!host)
            return;
        root.x = Math.min(Math.max(root.x, 0), Math.max(0, host.width - root.width));
        root.y = Math.min(Math.max(root.y, 0), Math.max(0, host.height - root.height));
    }

    // Tracks the host size this window's own geometry was last scaled
    // against -- see _scaleToHost() below, which needs the *previous* size
    // to compute a resize ratio (onWidthChanged/onHeightChanged only ever
    // hand us the *new* one). Seeded from the host's size at creation time
    // (Component.onCompleted below), then kept current by every place that
    // changes this window's relationship to the host: _scaleToHost() itself
    // and toggleMaximize() (both branches -- entering fill-the-host mode,
    // and leaving it back to a restored geometry that may itself no longer
    // match whatever the host resized to while maximized).
    property real _lastHostWidth: 0
    property real _lastHostHeight: 0

    // Scales this window's geometry proportionally with the host --
    // resizing the app's own window resizes/repositions every floating
    // window right along with it (not just keeps them from ending up
    // off-screen), the same "everything scales together" behavior a
    // percentage-based/flex layout gives, which is generally more useful
    // than a fixed pixel size becoming a shrinking fraction of a growing
    // window or an overflowing fraction of a shrinking one. Independent X/Y
    // scale factors (not one uniform ratio) so a host resize that's
    // asymmetric (e.g. only widened, not made taller) distorts floating
    // windows to match, rather than reacting only to whichever axis moved
    // least. See the Connections below for when this runs.
    function _scaleToHost() {
        var host = root.parent;
        if (!host)
            return;
        if (root.maximized) {
            // Still just fills -- nothing to scale, see toggleMaximize().
            root.width = host.width;
            root.height = host.height;
            root._lastHostWidth = host.width;
            root._lastHostHeight = host.height;
            return;
        }

        var scaleX = root._lastHostWidth > 0 ? host.width / root._lastHostWidth : 1;
        var scaleY = root._lastHostHeight > 0 ? host.height / root._lastHostHeight : 1;

        root.x *= scaleX;
        root.y *= scaleY;
        root.width = Math.max(root.minimumWidth, root.width * scaleX);
        // While minimized, root.height is pinned to the header rows' own
        // combined height (see toggleMinimize()), not a meaningful size to
        // scale -- scale the saved pre-minimize height instead, so
        // restoring later lands at a proportionally correct size rather
        // than whatever it happened to be when this window was collapsed.
        if (root.minimized)
            root._restoreHeight = Math.max(root.minimumHeight, root._restoreHeight * scaleY);
        else
            root.height = Math.max(root.minimumHeight, root.height * scaleY);

        root._clampPosition();

        root._lastHostWidth = host.width;
        root._lastHostHeight = host.height;
    }

    // Collapses to just the two header rows ("window shade"), hiding
    // contentArea/resize handles -- content stays alive and materialized,
    // just not painted, so nothing is lost by minimizing. Mutually
    // exclusive with maximized (FloatingWindowHeader.qml's own buttons
    // cross-disable to match) -- a no-op while maximized rather than
    // silently stacking both states.
    function toggleMinimize() {
        if (root.maximized)
            return;
        if (root.minimized) {
            root.minimized = false;
            root.height = root._restoreHeight;
        } else {
            root._restoreHeight = root.height;
            root.minimized = true;
            root.height = titleBar.height + paneHeader.height;
        }
    }

    // Fills the host entirely, remembering prior geometry to restore on
    // toggle-off. See _scaleToHost() above for what keeps a maximized
    // window filling the host if the host itself is resized meanwhile.
    function toggleMaximize() {
        var host = root.parent;
        if (!host || root.minimized)
            return;
        if (root.maximized) {
            root.maximized = false;
            root.x = root._restoreGeometry.x;
            root.y = root._restoreGeometry.y;
            root.width = root._restoreGeometry.width;
            root.height = root._restoreGeometry.height;
            // The restored geometry was valid before maximizing, but the
            // host may have resized while this window was maximized (see
            // _scaleToHost()'s own maximized branch) -- clamp it back into
            // bounds, and refresh the scale-tracking baseline to the
            // host's current size rather than leaving it stale from
            // whenever this window was last actually scaled.
            root._clampPosition();
            root._lastHostWidth = host.width;
            root._lastHostHeight = host.height;
        } else {
            root._restoreGeometry = Qt.rect(root.x, root.y, root.width, root.height);
            root.maximized = true;
            root.x = 0;
            root.y = 0;
            root.width = host.width;
            root.height = host.height;
            root._lastHostWidth = host.width;
            root._lastHostHeight = host.height;
        }
    }

    // --- Minimal controller-shim for PaneGrip.qml's cross-controller drag
    // dispatch (see class comment above) ---

    // Borrowed, not owned: FloatingWindowRegistry.host is the always-
    // mounted, whole-workspace Item every FloatingWindow already parents
    // under (see registerWindow() below), so it's already the right
    // stable coordinate space/z-order for a drag-ghost proxy, with no new
    // Item needed.
    readonly property Item dragLayer: Origami.FloatingWindowRegistry.host

    // Direct ports of PaneView.qml's own beginDrag()/endDrag() (verified
    // no other PaneView-internal dependency), just mapping into
    // root.dragLayer instead of root itself -- deliberately duplicated
    // rather than factored out, same "decoupled entirely" precedent
    // PaneGrip.qml's own class comment sets; revisit if a third consumer
    // of this exact shape shows up.
    function beginDrag(headerItem, proxyItem, localX, localY) {
        var pos = headerItem.mapToItem(root.dragLayer, localX, localY);
        proxyItem.x = pos.x;
        proxyItem.y = pos.y;
        proxyItem.visible = true;
        root.dragActive = true;
    }

    function endDrag(proxyItem) {
        proxyItem.visible = false;
        root.dragActive = false;
    }

    // Backs paneHeader's own _activeItem (materialize(_activeTab)) --
    // ignores `pane` entirely, since there's exactly one thing this
    // controller could ever materialize and it's already live (created in
    // Component.onCompleted or changePaneType() below, never lazily on
    // first read the way a real PaneView's own materialize() creates from
    // pane.component). Idempotent and side-effect-free, safe to call as
    // often as paneHeader's own bindings want to.
    function materialize(pane) {
        return root._contentItem;
    }

    // Ignores both arguments -- a FloatingWindow has exactly one thing it
    // could ever extract: its own content. Evacuates contentArea to
    // dragLayer *before* scheduling self-close, for two independent
    // reasons:
    //
    // - FloatingWindowRegistry.close() calls window.destroy(), which would
    //   destroy contentArea (and whatever live item it holds) too if it's
    //   still parented under root when that runs.
    // - PaneGrip.onReleased calls root.controller.endDrag(dragProxy) right
    //   after insertTab()/insertTabAtIndex(), in the same synchronous
    //   handler this function runs inside of. A synchronous self-close
    //   here would null out root.controller (this object) out from under
    //   that trailing call. Qt.callLater defers close() past the end of
    //   that handler -- the same "let the current turn finish first" idiom
    //   already used elsewhere in this codebase (PaneSplit.qml,
    //   PaneDrawer.qml, PaneTabBar.qml).
    function extractTab(areaId, paneId) {
        var item = contentArea;
        item.parent = root.dragLayer;
        item.visible = false;

        var hasRestorableType = root.windowComponent && root.windowViewType.length > 0;

        Qt.callLater(root.close);

        return {
            type: "pane",
            title: root.title,
            component: hasRestorableType ? root.windowComponent : null,
            viewType: hasRestorableType ? root.windowViewType : "",
            item: item,
            props: null
        };
    }

    // Whichever Item is actually showing in contentArea right now -- set
    // explicitly below rather than derived from contentArea.children
    // (ambiguous for the plain `content` case, which can hold more than
    // one child). Feeds _paneNode.item below (so paneHeader's own
    // materialize() shim can return it) and changePaneType()'s own
    // destroy-the-old-item step.
    property Item _contentItem: null

    // --- Registries for paneHeader's view-type switcher, borrowed (not
    // owned) from whatever real PaneView the app currently considers "the"
    // pane tree -- same singleton PaneHeader.qml's own sibling files
    // (Properties.qml) already read for the same "context reachable from
    // anywhere" reason (see PaneContext.qml's own class comment). Falls
    // back to empty when unset (e.g. this FloatingWindow constructed
    // before main.qml's own Component.onCompleted has run) -- matches
    // PaneHeader.qml's own graceful-degradation shape for an empty
    // viewTypeRegistry (typeButton just hides itself). ---
    readonly property QtObject _registrySource: Origami.PaneContext.controller
    readonly property var iconRegistry: root._registrySource ? root._registrySource.iconRegistry : ({})
    readonly property var viewTypeRegistry: root._registrySource ? root._registrySource.viewTypeRegistry : []
    readonly property var viewTypeCategories: root._registrySource ? root._registrySource.viewTypeCategories : []
    readonly property var componentRegistry: root._registrySource ? root._registrySource.componentRegistry : ({})

    // Always equals leafId below -- a FloatingWindow only ever has the one
    // pane, trivially "the active one in its own header" the same way a
    // real docked pane's PaneHeader would compute _active off PaneView's
    // real activeLeafId. Drives paneHeader's own bottom accent line.
    readonly property int activeLeafId: root.floatingWindowId

    // Synthetic single-"pane" tree node for paneHeader's own `node` --
    // same shape PaneTreeOps.qml's real "pane" nodes have (see
    // PaneHeader.qml's _activeTab: a node.type === "pane" is returned as
    // its own activeTab directly, no tabs-group drilling needed). A plain
    // object-literal binding, recomputed fresh (new identity) whenever any
    // dependency changes -- same "always reassigned wholesale" discipline
    // PaneView.qml's own `tree` follows, see its class comment.
    readonly property var _paneNode: ({
            type: "pane",
            id: root.floatingWindowId,
            title: root.title,
            component: root.windowComponent,
            viewType: root.windowViewType,
            item: root._contentItem,
            props: null
        })

    // paneHeader's own grip calls this when its right-click "閉じる" is
    // chosen -- there's nowhere else for this pane to go, so treat it the
    // same as the titlebar's own close button.
    function closeTab(areaId, paneId) {
        root.close();
    }

    // Backs paneHeader's view-type switcher (ViewTypePickerButton.
    // onViewTypeSelected) -- same destroy-old/create-new shape PaneView.
    // qml's own changePaneType() uses, just against root._contentItem
    // instead of an _itemCache entry (this window only ever has the one
    // item, so there's no cache to speak of).
    function changePaneType(paneId, newViewType, newTitle) {
        var component = root.componentRegistry[newViewType];
        if (!component)
            return;
        if (root._contentItem) {
            var oldItem = root._contentItem;
            root._contentItem = null;
            oldItem.destroy();
        }
        var item = component.createObject(contentArea);
        if (!item) {
            console.warn("FloatingWindow: failed to create view for " + newViewType);
            return;
        }
        item.anchors.fill = contentArea;
        root.windowComponent = component;
        root.windowViewType = newViewType;
        root.title = newTitle;
        root._contentItem = item;
    }

    Component.onCompleted: {
        root.floatingWindowId = Origami.FloatingWindowRegistry.registerWindow(root, root.title);
        // Seeds _scaleToHost()'s own ratio baseline -- registerWindow()
        // above reparents root under the host if it wasn't already (see
        // its own comment), so root.parent is guaranteed to be the host by
        // this point regardless of how this window was created.
        if (root.parent) {
            root._lastHostWidth = root.parent.width;
            root._lastHostHeight = root.parent.height;
        }
        if (root.hostedItem) {
            root.hostedItem.parent = contentArea;
            root.hostedItem.anchors.fill = contentArea;
            root.hostedItem.visible = true;
            root._contentItem = root.hostedItem;
        } else if (root.windowComponent) {
            var item = root.windowComponent.createObject(contentArea);
            if (item) {
                item.anchors.fill = contentArea;
                root._contentItem = item;
                if (root.restoreProps && item.paneRestore)
                    item.paneRestore(root.restoreProps);
            } else {
                console.warn("FloatingWindow: " + root.windowComponent.errorString());
            }
        } else if (contentArea.children.length === 1) {
            root._contentItem = contentArea.children[0];
        }
    }
    Component.onDestruction: Origami.FloatingWindowRegistry.unregisterWindow(root.floatingWindowId)

    // Whether this is the floating window last brought to front -- same
    // "active window" cue any real window manager gives the frontmost
    // window. Drives windowBackground's shadow strength below. (paneHeader
    // gets its own, separate "active" cue -- see activeLeafId above --
    // rather than reusing this one: "am I the OS-focused window" and "am I
    // the active pane within my own header" are different questions that
    // only happen to always agree here, since there's just the one pane.)
    readonly property bool _active: Origami.FloatingWindowRegistry.activeWindowId === root.floatingWindowId

    // target is a plain property binding, so this automatically retargets
    // itself if root.parent changes after construction (e.g. registerWindow()
    // above reparenting a declaratively-created instance into the host).
    Connections {
        target: root.parent
        function onWidthChanged() {
            root._scaleToHost();
        }
        function onHeightChanged() {
            root._scaleToHost();
        }
    }

    readonly property var _colors: StyleKit.Theme.paletteFor(StyleKit.Theme.window)

    // Raises this window on any press anywhere in it, content included --
    // a TapHandler rather than a blocking MouseArea, since a MouseArea
    // spanning the whole window would compete with/steal from interactive
    // child controls (buttons, text fields, ...) in `content`.
    TapHandler {
        acceptedButtons: Qt.AllButtons
        onPressedChanged: if (pressed)
            root.bringToFront()
    }

    Rectangle {
        id: windowBackground
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: root._colors.backgroundColor

        // Drop shadow so this reads as genuinely floating above the pane
        // tree/other floating windows behind it, not just a flat panel
        // that happens to be on top -- stronger while active, same
        // elevation cue most window managers give the focused window.
        // Declared on this Rectangle specifically (not layered on root
        // itself): its rounded, opaque silhouette is exactly the shape the
        // shadow should trace, and root has no clip of its own for this to
        // spill outside of.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: root._active ? 0.66 : 0.42
            shadowBlur: 0.84
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 3.6
        }
    }

    // Row 1: window chrome (title/minimize/maximize/close).
    FloatingWindowHeader {
        id: titleBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        windowItem: root
        title: root.title
        closable: root.closable
        minimized: root.minimized
        maximized: root.maximized
    }

    // Row 2: the real thing -- same PaneHeader.qml a docked pane gets
    // (grip/type-switcher/menus/center/end/modeSwitch), wired against this
    // file's own controller-shim above rather than a real PaneView.
    Origami.PaneHeader {
        id: paneHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleBar.bottom
        node: root._paneNode
        leafId: root.floatingWindowId
        currentIndex: 0
        controller: root
    }

    Item {
        id: contentArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: paneHeader.bottom
        anchors.bottom: parent.bottom
        clip: true
        visible: !root.minimized
    }

    // Traces the whole window's outline in one continuous stroke --
    // declared after titleBar/paneHeader/contentArea (which all paint over
    // windowBackground's own area, titleBar's rounded top corners
    // included, since it shares the same corner radius) so the border
    // shows uninterrupted around all four edges instead of only ever
    // appearing along the sides/bottom. A plain constant color, not
    // active-aware -- see windowBackground's own shadow and paneHeader's
    // own accent line above for this window's two separate focus cues:
    // this is just chrome.
    Rectangle {
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: "transparent"
        border.width: StyleKit.Units.borderWidth
        border.color: root._colors.borderColor
    }

    // Applies one resize-handle drag's accumulated delta. Shared by all 8
    // handles below rather than duplicated per-handle. For the "w"/"n"
    // edges, the new x/y is derived from `startWidth/Height - clampedWidth
    // /Height` (not the raw dx/dy) -- otherwise, once a drag pushes the
    // size past minimumWidth/minimumHeight, the position would keep
    // drifting on every further pixel of drag while the size stays
    // pinned at its floor.
    function _applyResize(edges, dx, dy, startX, startY, startW, startH) {
        var x = startX, y = startY, w = startW, h = startH;
        if (edges.indexOf("e") >= 0)
            w = Math.max(root.minimumWidth, startW + dx);
        if (edges.indexOf("w") >= 0) {
            w = Math.max(root.minimumWidth, startW - dx);
            x = startX + (startW - w);
        }
        if (edges.indexOf("s") >= 0)
            h = Math.max(root.minimumHeight, startH + dy);
        if (edges.indexOf("n") >= 0) {
            h = Math.max(root.minimumHeight, startH - dy);
            y = startY + (startH - h);
        }
        root.x = x;
        root.y = y;
        root.width = w;
        root.height = h;
    }

    readonly property var _resizeHandles: [
        { edges: "n", cursor: Qt.SizeVerCursor },
        { edges: "s", cursor: Qt.SizeVerCursor },
        { edges: "e", cursor: Qt.SizeHorCursor },
        { edges: "w", cursor: Qt.SizeHorCursor },
        { edges: "ne", cursor: Qt.SizeBDiagCursor },
        { edges: "sw", cursor: Qt.SizeBDiagCursor },
        { edges: "nw", cursor: Qt.SizeFDiagCursor },
        { edges: "se", cursor: Qt.SizeFDiagCursor }
    ]

    Repeater {
        // No resizing while collapsed (only the header rows are visible,
        // nothing to grab an edge/corner of) or while maximized (geometry
        // is pinned to the host; toggleMaximize() must restore first).
        model: (root.resizable && !root.minimized && !root.maximized) ? root._resizeHandles : []

        // Uniform edge/corner geometry: each pure edge spans the full
        // opposite axis inset by exactly one grabMargin from each side,
        // and each corner is a grabMargin*2 square straddling the corner
        // point by the same grabMargin -- the two line up flush with no
        // gap and no overlap (verified: a pure edge's far end sits at
        // exactly the adjacent corner square's near end).
        delegate: Item {
            id: handle
            required property var modelData
            required property int index

            readonly property bool hasN: handle.modelData.edges.indexOf("n") >= 0
            readonly property bool hasS: handle.modelData.edges.indexOf("s") >= 0
            readonly property bool hasE: handle.modelData.edges.indexOf("e") >= 0
            readonly property bool hasW: handle.modelData.edges.indexOf("w") >= 0
            readonly property real grabMargin: StyleKit.Units.smallSpacing * 1.5

            // Corners on top of edges, so a corner's hit area wins in the
            // small region where they'd otherwise be exactly adjacent.
            z: (handle.hasN || handle.hasS) && (handle.hasE || handle.hasW) ? 2 : 1

            x: handle.hasE ? root.width - handle.grabMargin : handle.hasW ? -handle.grabMargin : handle.grabMargin
            width: (handle.hasE || handle.hasW) ? handle.grabMargin * 2 : root.width - handle.grabMargin * 2
            y: handle.hasN ? -handle.grabMargin : handle.hasS ? root.height - handle.grabMargin : handle.grabMargin
            height: (handle.hasN || handle.hasS) ? handle.grabMargin * 2 : root.height - handle.grabMargin * 2

            MouseArea {
                anchors.fill: parent
                cursorShape: handle.modelData.cursor
                hoverEnabled: false

                property real _startX
                property real _startY
                property real _startW
                property real _startH
                property point _start

                onPressed: mouse => {
                    root.bringToFront();
                    _start = mapToItem(root.parent, mouse.x, mouse.y);
                    _startX = root.x;
                    _startY = root.y;
                    _startW = root.width;
                    _startH = root.height;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    var p = mapToItem(root.parent, mouse.x, mouse.y);
                    root._applyResize(handle.modelData.edges, p.x - _start.x, p.y - _start.y, _startX, _startY, _startW, _startH);
                }
            }
        }
    }
}
