pragma Singleton
import QtQuick

// App-wide registry of currently-open FloatingWindow instances (in-app
// MDI-style panels, see FloatingWindow.qml/FloatingWindowHost.qml) --
// mirrors PaneWindowRegistry.qml's shape, generalized from real OS windows
// to plain Items reparented into one shared host layer.
//
// `windows` is always reassigned wholesale rather than mutated in place
// (push/splice) -- QML array-mutation methods fire no change notification,
// so anything bound to `FloatingWindowRegistry.windows` would never see an
// update otherwise. Same discipline PaneView.qml's own `tree` property and
// PaneWindowRegistry.windows already follow.
QtObject {
    id: root

    // Set exactly once, by FloatingWindowHost.qml's Component.onCompleted.
    // A FloatingWindow that registers before this is set is still tracked
    // in `windows` (just not yet reparented) -- see registerWindow below.
    property Item host: null

    property var windows: []  // [{ id, window, title }]

    property int _nextId: 1
    // Kept well below ToastNotification.qml's z: 9999, so toasts always
    // stay above floating windows regardless of how many are open/raised.
    property int _nextZ: 1

    // The floating window last brought to front -- read by FloatingWindow.
    // qml's own _active to decide its border/shadow highlight, same
    // "active window" cue any real window manager gives the frontmost
    // window. -1 when no floating window has ever been focused, which
    // correctly matches no window at all (property equality against a
    // real window's id, always >= 1, never matches).
    property int activeWindowId: -1

    function registerWindow(window, title) {
        var id = root._nextId++;
        window.z = root._nextZ++;
        root.activeWindowId = id;
        if (root.host && window.parent !== root.host)
            window.parent = root.host;
        root.windows = root.windows.concat([
            {
                id: id,
                window: window,
                title: title
            }
        ]);
        return id;
    }

    function unregisterWindow(id) {
        root.windows = root.windows.filter(function (entry) {
            return entry.id !== id;
        });
        if (root.activeWindowId === id)
            root.activeWindowId = -1;
    }

    function bringToFront(id) {
        var entry = root.windows.find(function (entry) {
            return entry.id === id;
        });
        if (entry) {
            entry.window.z = root._nextZ++;
            root.activeWindowId = id;
        }
    }

    // Convenience for dynamic/imperative creation (e.g. spawning a fresh
    // instance of some panel from a menu action). Declarative use (a
    // FloatingWindow written directly as a normal child anywhere in the
    // tree, the same way RenameDialog.qml is) doesn't need this -- it
    // self-registers via its own Component.onCompleted either way, see
    // FloatingWindow.qml.
    function open(component, properties) {
        if (!root.host) {
            console.warn("FloatingWindowRegistry.open: host not mounted yet");
            return null;
        }
        var win = component.createObject(root.host, properties || {});
        if (!win)
            console.warn("FloatingWindowRegistry.open: " + component.errorString());
        return win;
    }

    function close(id) {
        var entry = root.windows.find(function (entry) {
            return entry.id === id;
        });
        if (entry)
            entry.window.destroy();
    }

    // Writes out every currently-open FloatingWindow as a JSON-able plain
    // array -- same "viewType string + optional paneSerialize() props"
    // shape PaneView.qml's own _serializeNode() uses for a docked "pane"
    // node, plus geometry/window-state fields a FloatingWindow additionally
    // needs (unlike a docked pane, a FloatingWindow *is* its own geometry).
    // A window whose windowViewType is empty (plain `content` children, or
    // a hostedItem moved in from a docked pane -- see FloatingWindow.qml's
    // own windowViewType comment) is skipped: there's no Component to hand
    // restoreWindows() below, so it could never be recreated after a
    // reload -- same graceful-drop PaneView.qml's own restoreTree() gives
    // an unknown viewType.
    function serializeWindows() {
        return root.windows.map(function (entry) {
            return entry.window;
        }).filter(function (win) {
            return win.windowViewType.length > 0;
        }).map(function (win) {
            return {
                viewType: win.windowViewType,
                title: win.title,
                props: (win._contentItem && win._contentItem.paneSerialize) ? win._contentItem.paneSerialize() : {},
                x: win.x,
                y: win.y,
                width: win.width,
                height: win.height,
                minimized: win.minimized,
                maximized: win.maximized
            };
        });
    }

    // Restores previously-serialized FloatingWindows (see serializeWindows()
    // above), creating one `component` (a FloatingWindow.qml, per the
    // caller) instance per entry. `componentRegistry` is passed in rather
    // than assumed -- this registry has no notion of view types itself
    // (that's app-specific, see this file's own class comment on staying a
    // generalized version of PaneWindowRegistry.qml) -- the caller already
    // has the same registry it hands PaneView.componentRegistry. An entry
    // whose viewType isn't in componentRegistry is dropped, same
    // graceful-degradation PaneView.qml's own restoreTree() gives a pane
    // whose viewType has disappeared since it was saved.
    function restoreWindows(component, saved, componentRegistry) {
        (saved || []).forEach(function (entry) {
            var viewComponent = componentRegistry[entry.viewType];
            if (!viewComponent) {
                console.warn("FloatingWindowRegistry.restoreWindows: unknown viewType, dropping saved window:", entry.viewType);
                return;
            }
            var win = root.open(component, {
                title: entry.title,
                windowComponent: viewComponent,
                windowViewType: entry.viewType,
                restoreProps: entry.props || {},
                x: entry.x,
                y: entry.y,
                width: entry.width,
                height: entry.height
            });
            if (!win)
                return;
            // Applied after creation (not as initial properties): both
            // toggle functions snapshot/restore against whatever geometry
            // the window already has, which is the x/y/width/height just
            // set above.
            if (entry.minimized)
                win.toggleMinimize();
            if (entry.maximized)
                win.toggleMaximize();
        });
    }
}
