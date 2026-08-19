pragma Singleton
import QtQuick

// App-wide registry of currently-open PaneWindow instances (panes/views
// popped out into their own top-level window, see PaneWindow.qml/
// PaneHeader.qml's "別ウィンドウで開く"/"別ウィンドウに移動" and main.qml's
// "ファイル -> 設定"). A plain singleton for the same reason PaneContext.qml
// is one -- see its own class comment.
//
// `windows` is always reassigned wholesale rather than mutated in place
// (push/splice) -- QML array-mutation methods fire no change notification,
// so anything bound to `PaneWindowRegistry.windows` (e.g. PaneManager.qml's
// open-windows list) would never see an update otherwise. Same discipline
// PaneView.qml's own `tree` property already follows.
QtObject {
    id: root

    property var windows: []

    function registerWindow(window, title, viewType) {
        root.windows = root.windows.concat([
            {
                window: window,
                title: title,
                viewType: viewType
            }
        ]);
    }

    function unregisterWindow(window) {
        root.windows = root.windows.filter(function (entry) {
            return entry.window !== window;
        });
    }
}
