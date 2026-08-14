import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Generic top-level window for hosting a single pane's content outside the
// pane tree. Two mutually exclusive ways to populate it, set via
// createObject()'s initial-properties dict (so both are already resolved
// before Component.onCompleted below runs):
//
//   paneWindowComponent.createObject(parent, { paneComponent: someComponent, title: "..." })
//
// creates a brand-new instance (e.g. PaneHeader.qml's "別ウィンドウで開く" --
// a fresh copy of that view type, the existing pane untouched), while
//
//   paneWindowComponent.createObject(parent, { hostedItem: existingItem, title: "..." })
//
// hosts an already-materialized, still-live Item (e.g. "別ウィンドウに移動" --
// the caller is expected to have already removed it from wherever it used
// to live, typically via PaneView.detachPane(), so this window becomes its
// new, only parent).
QQC2.ApplicationWindow {
    id: root

    width: 720
    height: 480
    minimumWidth: 160
    minimumHeight: 160

    property Component paneComponent: null
    property Item hostedItem: null
    // For PaneWindowRegistry's benefit only (see below) -- not used for
    // anything else in this file, just carried through so PaneManager.qml
    // can show/pick an icon for this window later without having to guess
    // it back out of `title`.
    property string paneViewType: ""

    Item {
        id: contentHost
        anchors.fill: parent
    }

    Component.onCompleted: {
        var item = root.hostedItem || (root.paneComponent ? root.paneComponent.createObject(contentHost) : null);
        if (item) {
            item.parent = contentHost;
            item.anchors.fill = contentHost;
            item.visible = true;
        }
        // A dynamically createObject()'d top-level Window doesn't reliably
        // map to screen from its default `visible: true` alone (no actual
        // property *change* occurs to trigger showing it) -- show it here
        // so every caller gets this for free instead of each needing to
        // remember it (main.qml's _openSettings() already does its own
        // show()/raise()/requestActivate() too, for the separate "reuse an
        // already-open window" case on repeat opens -- harmless overlap
        // with this, not a conflict).
        root.show();
        root.raise();
        root.requestActivate();

        PaneWindowRegistry.registerWindow(root, root.title, root.paneViewType);
    }

    Component.onDestruction: PaneWindowRegistry.unregisterWindow(root)
}
