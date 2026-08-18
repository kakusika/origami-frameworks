import QtQuick
import StyleKit 1.0 as StyleKit

// Recursive dispatcher that shows PaneSplit/PaneDrawer/PaneLeaf depending on
// node.type, and decides whether that node gets a "this is a group" frame
// (margin + border) at all.
//
// That decision is written as an exclusion -- every node type except
// "split" (a purely structural divider), "pane" (a bare standalone
// view), and "toolbar" (also a bare single view, just fixed-size and
// routed to PaneToolbar.qml instead of PaneLeaf.qml -- see PaneSplit.qml's
// own fixed-size handling) is framed -- rather than an allow-list of the
// group types that currently exist ("tabs", "drawer"). Since PaneNode is
// the single place every node in the tree passes through, this is the
// only place the decision needs to live: a future group type is framed
// automatically, with no other file to update.
//
// PaneNode only decides *whether*, not *where*: the actual margin/border
// is drawn by whichever component gets loaded (PaneLeaf.qml/PaneDrawer.qml),
// via the `framed` property passed down below, because only that component
// knows where its own "interactive strip" (PaneLeaf's tab bar, PaneDrawer's
// collapse header) ends and the framed payload begins -- that strip sits
// outside the frame, same as it always has, and PaneNode has no visibility
// into that internal split to draw the border itself.
//
// PaneSplit.qml uses this file (PaneNode) as a child directly, so referencing
// PaneSplit/PaneDrawer/PaneLeaf as static types (via import) from here would
// create a circular type dependency, which the QML engine refuses to load
// with "Cyclic dependency detected". To break the cycle, they're instead
// referenced through deferred loading via Loader.source (a URL string)
// rather than Loader.sourceComponent.
//
// The source string is an absolute qrc: URL rather than a path relative to
// this file: a plain relative string (e.g. "groups/PaneSplit.qml") resolves
// against the URL of whichever component is currently being loaded further
// up the Loader chain -- not against this file's own location -- once
// PaneNode is reused as a Repeater delegate several levels deep (e.g. inside
// PaneSplit.qml, itself loaded dynamically). An absolute URL sidesteps that
// ambiguity entirely.
//
// As long as node.type doesn't change, source stays the same string, so
// cloning the tree (reassigning the reference) alone doesn't recreate the
// Loader itself (i.e. the lifetime of the Item reused under PaneLeaf isn't
// affected by this Loader's lifecycle unless node.type changes).
Loader {
    id: root
    property var node
    property var controller

    // Whether some ancestor already drew a "group frame" (margin+border)
    // that this node's own bounds sit inside of. Set to `true` by
    // PaneDrawer.qml's own nested PaneNode (see its comment) -- never by
    // PaneSplit.qml, since a "split" never draws a frame itself and
    // always gives its children visual breathing room (the divider
    // handle) instead of sitting flush against an outer border. Without
    // this, a "tabs"/"drawer" node nested directly inside a "drawer"
    // (e.g. dropping a pane onto an existing drawer's own child via its
    // drawer-top/drawer-bottom zone) would draw its own frame
    // immediately inside the outer drawer's already-drawn one, looking
    // like a doubled border.
    property bool ancestorFramed: false

    // Per-corner radius passthrough to whichever item gets loaded below
    // (currently only PaneLeaf.qml has matching properties) -- 0 by
    // default, so nothing changes for any caller that doesn't set these.
    // See PaneDrawer.qml's body PaneNode for the one caller that does,
    // and PaneLeaf.qml's own properties for the reasoning.
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0

    // Passthrough to the loaded item's own `active` property, if it has
    // one (currently only PaneLeaf.qml does -- see its comment). Default
    // true, so every caller that doesn't explicitly set this (split
    // cells, top-level workspace panes) is unaffected; PaneDrawer.qml's
    // own body/overlay Repeaters are the one caller that sets this false
    // for every child except the currently selected one.
    property bool active: true

    // Passthrough to the loaded item's own `splitOrientation` property,
    // if it has one (currently only PaneDrawer.qml does, to force its own
    // rail orientation when it's a direct child of a "split" -- see its
    // class comment). "" by default, so every caller that doesn't
    // explicitly set this is unaffected; PaneSplit.qml's own Repeater
    // delegate is the one caller that does, setting it to that split's
    // own node.orientation.
    property string splitOrientation: ""

    readonly property string _prefix: "qrc:/qt/qml/la/cettila/Origami/qml/pane/"

    // Whether the loaded item declares a `fixedSizePx` property (duck-
    // typed: PaneToolbar.qml and PaneDrawer.qml both do; PaneLeaf.qml and
    // PaneSplit.qml don't). When true, `fixedSizePx` below reflects
    // whatever the item currently reports -- including live changes (e.g.
    // a drawer toggling between 0 and collapsedDrawerSize as it
    // expands/collapses). When false, `fixedSizePx` is 0 and the cell
    // takes a proportional share.
    property bool _itemHasFixedSize: false
    property real _itemFixedSizePx: 0

    // This cell's own fixed size along its parent split's axis, in px, or
    // 0 if it should take a proportional share like an ordinary pane
    // instead. Sourced entirely from the loaded item's own `fixedSizePx`
    // property (if it declares one) so each node type controls its own
    // sizing policy:
    //   - PaneToolbar: always fixed (StyleKit.Units.toolbarSize or
    //     node.props.fixedSize override)
    //   - PaneDrawer:  fixed when collapsed (railSize), 0 when expanded
    //   - PaneLeaf / PaneSplit: no property → always 0 (proportional)
    // Any future node type that wants a fixed or stateful size just needs
    // to declare `fixedSizePx` on itself; PaneNode and PaneSplit need no
    // further changes.
    readonly property real fixedSizePx: root._itemHasFixedSize ? root._itemFixedSizePx : 0

    source: {
        if (!node)
            return "";
        if (node.type === "split")
            return root._prefix + "groups/PaneSplit.qml";
        if (node.type === "drawer")
            return root._prefix + "groups/PaneDrawer.qml";
        if (node.type === "toolbar")
            return root._prefix + "PaneToolbar.qml";
        return root._prefix + "PaneLeaf.qml";
    }

    onLoaded: {
        // Bound before node/controller below: assigning those two
        // synchronously fires PaneLeaf.qml's own onNodeChanged/
        // onControllerChanged, which immediately calls _updateContent()
        // -- if `active` weren't already bound by then, that first call
        // would run against PaneLeaf's default `active: true` and
        // materialize regardless of what this Loader's own `active`
        // is actually meant to be.
        if (item.hasOwnProperty("active"))
            item.active = Qt.binding(function () {
                return root.active;
            });
        item.node = Qt.binding(function () {
            return root.node;
        });
        item.controller = Qt.binding(function () {
            return root.controller;
        });
        if (item.hasOwnProperty("framed"))
            item.framed = Qt.binding(function () {
                return !!root.node && root.node.type !== "split" && root.node.type !== "pane" && root.node.type !== "toolbar" && !root.ancestorFramed;
            });
        if (item.hasOwnProperty("splitOrientation"))
            item.splitOrientation = Qt.binding(function () {
                return root.splitOrientation;
            });
        if (item.hasOwnProperty("topLeftRadius")) {
            item.topLeftRadius = Qt.binding(function () {
                return root.topLeftRadius;
            });
            item.topRightRadius = Qt.binding(function () {
                return root.topRightRadius;
            });
            item.bottomLeftRadius = Qt.binding(function () {
                return root.bottomLeftRadius;
            });
            item.bottomRightRadius = Qt.binding(function () {
                return root.bottomRightRadius;
            });
        }
        // Duck-typed fixed-size: if the loaded item declares `fixedSizePx`
        // (PaneToolbar, PaneDrawer), mirror it into _itemFixedSizePx so
        // `fixedSizePx` above (and therefore PaneSplit's layout) updates
        // automatically whenever the item's own value changes (e.g. a
        // drawer toggling between 0 and railSize). Items without the
        // property (PaneLeaf, PaneSplit) leave _itemHasFixedSize false so
        // `fixedSizePx` stays 0 -- no type-name checks needed anywhere.
        if (item.hasOwnProperty("fixedSizePx")) {
            root._itemHasFixedSize = true;
            root._itemFixedSizePx = Qt.binding(function () {
                return root.item ? root.item.fixedSizePx : 0;
            });
        } else {
            root._itemHasFixedSize = false;
            root._itemFixedSizePx = 0;
        }
    }

    // When the Loader unloads (source set to "" or node.type changes and
    // a new load starts), clear the fixed-size mirror so `fixedSizePx`
    // doesn't hold a stale value while the new item is loading.
    onStatusChanged: {
        if (root.status !== Loader.Ready) {
            root._itemHasFixedSize = false;
            root._itemFixedSizePx = 0;
        }
    }
}
