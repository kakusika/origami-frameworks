pragma Singleton
import QtQuick
import la.cettila.Origami 1.0

// Thin, read-mostly mirror of "what background image (if any) should
// panes/the main window draw, and how opaque". The actual feature --
// picking an image, choosing/tuning an effect, persisting any of it -- is
// the consuming app's job (e.g. cettila-view-settings's own Background.qml
// + BackgroundSettings cxx-qt type); this singleton only exists so
// origami's own PaneLeaf.qml/PaneDrawer.qml (which need to know this to
// render at all) don't have to depend on a crate that itself depends on
// origami, which a straight move of the whole feature into that crate
// would have required. Seeded once from BackgroundState (this crate's own
// read-only mirror of the persisted values, backed by origami-config
// directly) at construction so panes render correctly even before the
// settings screen has ever been opened this session; the consuming app's
// own settings singleton calls refreshImage()/refreshOpacity()/
// notifyRendered() on this one after every change so already-open panes
// pick it up immediately too.
QtObject {
    id: backdrop

    readonly property BackgroundState _state: BackgroundState {}

    // Absolute path to the picked background image, or "" if unset. Every
    // "is a background configured at all" ternary across the app
    // (PaneLeaf.qml/PaneDrawer.qml/Explorer.qml/Properties.qml/main.qml)
    // reads this, not displayImagePath -- whether a background exists
    // doesn't depend on which effect (if any) is applied to it.
    property string imagePath: backdrop._state.image_path()

    // How opaque (0.0-1.0) a pane draws its own background when imagePath
    // is non-empty. Ignored (panes stay fully opaque) while imagePath is
    // "".
    property real paneOpacity: backdrop._state.pane_opacity()

    // Path of the last successfully rendered effect output pushed via
    // notifyRendered(), or "" if none this session -- see
    // cettila-view-settings's Background.qml for why this isn't restored
    // from a previous session's cache file on startup.
    property string renderedPath: ""

    // Bumped by notifyRendered() on every successful regeneration -- see
    // the old Background.qml's own comment on why (background_cache_path
    // is a single fixed filename, so a plain `source: ...renderedPath`
    // binding wouldn't notice the file's bytes changed on disk).
    property int renderVersion: 0

    // What main.qml's background Image should actually load: the rendered
    // effect output once one exists for the current settings, otherwise
    // the plain source image.
    readonly property string displayImagePath: backdrop.renderedPath.length > 0 ? backdrop.renderedPath : backdrop.imagePath

    // Re-reads imagePath from the persisted setting and clears
    // renderedPath (whatever was last rendered no longer matches).
    // Called by cettila-view-settings's Background.qml after
    // setImagePath()/clearImage().
    function refreshImage() {
        backdrop.imagePath = backdrop._state.image_path();
        backdrop.renderedPath = "";
    }

    // Re-reads paneOpacity from the persisted setting. Doesn't touch
    // renderedPath -- opacity doesn't affect the rendered pixels
    // themselves, just how much of it shows through a pane. Called by
    // cettila-view-settings's Background.qml after setPaneOpacity().
    function refreshOpacity() {
        backdrop.paneOpacity = backdrop._state.pane_opacity();
    }

    // Called by cettila-view-settings's Background.qml after a successful
    // regenerate(). Also called (with "") whenever an effect parameter
    // changes there, invalidating whatever was last rendered.
    function notifyRendered(path) {
        backdrop.renderedPath = path;
        if (path.length > 0)
            backdrop.renderVersion += 1;
    }
}
