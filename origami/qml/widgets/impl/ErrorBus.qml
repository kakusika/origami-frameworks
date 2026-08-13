pragma Singleton
import QtQuick

// "Report an error from anywhere, show it in StatusBarError.qml" -- a
// plain QML singleton (same mechanism Theme.qml/Units.qml/PaneContext.qml
// already use, see origami/build.rs and PaneContext.qml's own comment for
// why a hand-rolled C++ Q_OBJECT context property isn't used instead).
//
// A signal rather than a stored `property string message` deliberately:
// StatusBarError.qml only ever needs "a new error just happened", not "what is
// the current error" (there's no single current error -- multiple views
// can report independently, and re-reporting the same text twice in a row
// should still restart the auto-dismiss timer, which a property's
// change-only notification wouldn't do).
//
// Any view can call ErrorBus.reportError("...") directly (io_error-backed
// views do this via IoErrorBanner.qml's own onMessageChanged hook, so
// existing per-view banners keep working unchanged and additionally surface
// here); Rust-only code without a QML frontend has no path to this
// singleton and should keep using its own qproperty/eprintln! for now.
QtObject {
    id: root

    signal errorReported(string message)

    function reportError(message) {
        root.errorReported(message);
    }
}
