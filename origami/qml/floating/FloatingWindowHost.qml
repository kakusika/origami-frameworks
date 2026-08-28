import QtQuick
import la.cettila.Origami 1.0 as Origami

// Mount exactly once, app-wide (see cettila's main.qml for the actual
// mount point/anchoring rationale). Deliberately has no visual chrome of
// its own and no MouseArea -- a plain Item with no painted content and no
// input handling doesn't intercept clicks outside its children's own hit
// areas, so this can safely span the whole workspace without blocking
// input to whatever's underneath it (same reasoning as PaneView's own
// dragLayer).
Item {
    id: root

    Component.onCompleted: Origami.FloatingWindowRegistry.host = root
}
