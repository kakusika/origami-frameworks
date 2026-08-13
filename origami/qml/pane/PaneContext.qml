pragma Singleton
import QtQuick

// "A context property reachable from anywhere" for whichever PaneView the
// app currently considers "the" pane tree -- see Properties.qml (in
// crates/views/properties), the first and so far only consumer. main.qml
// assigns `controller` to its own PaneView instance (id: mainPaneView)
// once created; any other QML file can then read
// PaneContext.controller.activeLeafId / call
// PaneContext.controller.resolveActivePane(...) without the reference
// having to be threaded through as a property down the pane tree itself.
//
// A plain QML singleton (same mechanism Theme.qml/Units.qml already use,
// see origami/build.rs) rather than a hand-rolled C++ Q_OBJECT context
// property -- see TASKS.md's "Property View" section for why: every
// existing cxx_qt_build `.cpp_file()` in this codebase is either a
// cxx-qt-generated bridge or a moc-free helper, so a plain-C++
// `Q_OBJECT`/moc class would be unproven territory build-wise, while this
// singleton is functionally identical for QML consumers.
QtObject {
    id: root

    property QtObject controller: null
}
