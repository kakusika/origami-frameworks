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
}
