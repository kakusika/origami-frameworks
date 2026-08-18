import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// One grid cell representing a file or directory entry: an icon (or, for
// callers that opt in via `thumbnailSource`, a thumbnail preview once it
// loads) plus its name below. Extracted from ImagePickerPage.qml and
// cettila-view-explorer's ExplorerGrid.qml, which had near-identical
// delegates (icon, symlink emblem, wrapped label, transparent hover-
// outline background) before this existed. Knows nothing about any
// particular model -- callers bind `text`/`isDir`/`iconName`/etc. to
// whatever role names their own model uses, and handle the inherited
// `clicked()` signal themselves (open a directory vs. pick/select a
// file are call-site decisions, not this component's).
QQC2.ItemDelegate {
    id: root

    property bool isDir: false
    property string iconName: ""
    property bool isSymlink: false
    property bool isBrokenSymlink: false

    // Left unset ("", the default) for entries with no preview --
    // directories, or callers (like ExplorerGrid) that don't want
    // thumbnails at all. Only ever tried for non-directory entries; see
    // the Image below.
    property url thumbnailSource: ""

    // Off for callers that want an icon-only grid (denser packing at
    // small sizes -- CollectionsView.qml's own grid display-options
    // toggle) -- on by default so every existing caller (ExplorerGrid.qml/
    // ExplorerTree.qml) keeps its label unchanged.
    property bool showLabel: true

    // Off (the default) keeps the original icon-above-label ColumnLayout,
    // sized off iconArea's own available space -- every grid caller
    // (ExplorerGrid.qml, CollectionsView.qml). On switches to an icon-
    // beside-label RowLayout for list/tree rows (ExplorerTree.qml), where
    // row height is fixed and set by the caller rather than derived from
    // available square space.
    property bool horizontal: false

    // Only read in horizontal mode -- vertical mode keeps sizing its icon
    // off iconArea's own resolvedIconSize instead (see below).
    property real iconSize: StyleKit.Units.iconSizes.small

    // Opt-in escape hatch from the active style's own ItemDelegate
    // padding -- off by default, see the Binding blocks below for the
    // full reasoning on why this exists and why it's independent of
    // `horizontal`.
    property bool flushPadding: false

    // Selection highlight, driven by the caller's own selection model
    // (e.g. ExplorerGridModel's IsSelected role) -- distinct from
    // hover/press, computed entirely within this file (see tapArea below).
    property bool selected: false

    // Drag-out opt-in, unset by default: callers that don't want dragging
    // (ImagePickerPage.qml -- still a plain pick-a-file dialog with no
    // selection/drag concept of its own yet) get none of this. Computing
    // dragMimeData is the call site's job, not this file's -- only the
    // caller knows whether this row's own path is part of a wider
    // multi-selection (see ExplorerGrid.qml/ExplorerTree.qml).
    property bool dragEnabled: false
    property var dragMimeData: ({})

    // A grabToImage() snapshot of this tile, taken at press-time (see
    // tapArea's own onPressed below) and used as the dragged pixmap (see
    // dragProxy's Drag.imageSource) -- without it, Drag.dragType.
    // Automatic's OS-level QDrag shows no custom pixmap at all on most
    // platforms/compositors, which doesn't read as "picking up" anything.
    // Cached per-press rather than bound continuously (grabToImage is a
    // real GPU readback, too costly to redo every frame the tile is
    // merely visible).
    property url _dragImage: ""
    property real _dragHotSpotX: 0
    property real _dragHotSpotY: 0

    // Dims the source tile while actually being dragged, so the floating
    // drag-image (not this tile) reads as the thing being moved --
    // matches the "lifted, semi-transparent original" look most desktop
    // file managers use.
    opacity: tapArea.drag.active ? 0.4 : 1.0

    // A caller-adjustable cell size (CollectionsView.qml's own gridAspectRatio
    // slider) can end up shorter than contentItem's icon + label actually
    // need -- clip rather than let the overflow bleed into whichever
    // delegate GridView/ListView happens to have positioned just below.
    clip: true

    // New: carries the click's keyboard modifiers (Qt::KeyboardModifiers),
    // which the inherited clicked() (still explicitly re-emitted below,
    // for existing callers like ImagePickerPage.qml) never exposes --
    // ExplorerGrid.qml/ExplorerTree.qml need this to tell a plain click
    // from a Ctrl/Shift-click for multi-select.
    signal tapped(int modifiers)

    // Right-click (or press-and-hold, on a platform where MouseArea
    // synthesizes that as a right-click) -- x/y are this tile's own
    // local coordinates, so a caller can pass them straight through to a
    // QQC2.Menu's popup(anchorItem, x, y) to open right where the click
    // landed. Kept separate from tapped() above rather than folding a
    // "which button" flag into it, since a context-menu request is a
    // different kind of event entirely (never a selection/activation),
    // not just another modifier combination on the same one.
    signal contextMenuRequested(real x, real y)

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    // Off by default -- padding is left alone, coming entirely from
    // whichever QQC2 style is active (Ayame's own widgets/delegates/
    // ItemDelegate.qml sets `padding: StyleKit.Units.smallSpacing`; this
    // file has no opinion of its own and never should). A caller flips
    // this on only when it genuinely needs a flush, style-independent
    // row -- ExplorerTree.qml's dense Dolphin-style tree rows, where the
    // row height itself is computed tightly around the icon's own fixed
    // iconSize (see ExplorerTree.qml's own rowPadding/rowIconSize) and
    // the style's own padding would eat into that same fixed box instead
    // of adding to it, clipping the icon. Deliberately independent of
    // `horizontal` -- orientation and padding are unrelated axes; a
    // horizontal caller that's fine with the active style's own padding
    // (there may be one some day) shouldn't be forced to fight it.
    Binding {
        target: root
        property: "topPadding"
        value: 0
        when: root.flushPadding
    }
    Binding {
        target: root
        property: "bottomPadding"
        value: 0
        when: root.flushPadding
    }
    Binding {
        target: root
        property: "leftPadding"
        value: 0
        when: root.flushPadding
    }
    Binding {
        target: root
        property: "rightPadding"
        value: 0
        when: root.flushPadding
    }

    // The default style-drawn background is an opaque rectangle that
    // would paint over the grid's own background -- same stock Kirigami/
    // Breeze look as before extraction: no fill, just a highlight-
    // colored outline on hover/press, plus (new) a filled highlight for an
    // actual selection -- matches Dolphin's own "selected rows get a
    // filled background, hovered rows just an outline" convention.
    background: Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: StyleKit.Units.cornerRadius
        color: root.selected ? Qt.rgba(root.colors.highlightColor.r, root.colors.highlightColor.g, root.colors.highlightColor.b, 0.3) : "transparent"
        // down (AbstractButton's own press state) no longer updates once
        // tapArea below owns real press handling -- tapArea.pressed
        // stands in for it.
        border.width: (root.hovered || tapArea.pressed || root.selected) ? StyleKit.Units.borderWidth : 0
        border.color: root.colors.highlightColor
    }

    contentItem: Loader {
        sourceComponent: root.horizontal ? horizontalContent : verticalContent
    }

    // Icon-beside-label row for list/tree callers (ExplorerTree.qml).
    // Unlike verticalContent below, the icon is a fixed root.iconSize
    // square (the caller owns row height, there's no leftover-space
    // square to derive it from) and the label sits to its right,
    // single-line with tail elision -- matches how a file-manager list
    // view (not a grid) truncates a long name.
    Component {
        id: horizontalContent
        RowLayout {
            // Loader (contentItem above) doesn't stretch a loaded item to
            // its own size on its own -- without this the RowLayout would
            // just sit at its own implicit (icon + label natural width)
            // size instead of the tile's actual bounds, and Label's own
            // Layout.fillWidth below would have nothing real to fill.
            anchors.fill: parent
            // Left/right-only breathing room between the icon/label
            // content and the selection/hover border drawn by `background`
            // above -- independent of topPadding/bottomPadding/
            // leftPadding/rightPadding (which flushPadding forces to 0,
            // see the Binding blocks above) and of whatever the active
            // style's own default padding is: a caller like ExplorerTree.qml
            // still wants the icon to sit flush against the row's own
            // tightly-computed height (no top/bottom margin here, so
            // iconSize keeps fitting exactly), but the highlight border
            // hugging the text right at its edges reads cramped either way,
            // regardless of that caller's own row-height math.
            anchors.leftMargin: StyleKit.Units.smallSpacing
            anchors.rightMargin: StyleKit.Units.smallSpacing
            spacing: StyleKit.Units.smallSpacing

            Item {
                // RowLayout stretches a child to the row's full height by
                // default unless it has its own Layout.alignment -- without
                // this, this Item (meant to stay a fixed iconSize square)
                // would instead stretch to whatever the row's actual
                // available height is (which only ever happens to equal
                // iconSize when the active style's own ItemDelegate padding
                // is zeroed out via flushPadding), stretching the Icon
                // below it (anchors.fill: parent) into a non-square shape
                // any time real padding is present instead.
                Layout.preferredWidth: root.iconSize
                Layout.preferredHeight: root.iconSize
                Layout.alignment: Qt.AlignVCenter

                Origami.Icon {
                    anchors.fill: parent
                    visible: root.isDir || thumbnail.status !== Image.Ready
                    source: root.iconName
                    color: root.colors.textColor
                }

                Image {
                    id: thumbnail
                    anchors.fill: parent
                    visible: !root.isDir && status === Image.Ready
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    source: root.isDir ? "" : root.thumbnailSource
                    sourceSize.width: root.iconSize
                    sourceSize.height: root.iconSize
                }

                Origami.Icon {
                    visible: root.isSymlink
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.5
                    height: parent.height * 0.5
                    source: root.isBrokenSymlink ? "emblem-warning" : "emblem-symbolic-link"
                    color: root.isBrokenSymlink ? root.colors.negativeTextColor : root.colors.textColor
                }
            }

            Origami.Label {
                visible: root.showLabel
                text: root.text
                Layout.fillWidth: true
                // Same reasoning as the icon Item's own Layout.alignment
                // above -- without it, Label (Text's default
                // verticalAlignment is AlignTop) would sit pinned to the
                // top of the row's full stretched height instead of
                // centered alongside the icon whenever real padding
                // shrinks the row's available content height below its
                // own full bounds.
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: verticalContent
        ColumnLayout {
            // Loader (contentItem above) doesn't stretch a loaded item to
            // its own size on its own -- without this, this ColumnLayout
            // would sit at its own implicit size instead of the tile's
            // actual bounds (this used to be contentItem directly, with no
            // Loader in between, where Control itself handled the sizing
            // -- the horizontal/vertical mode switch above is what
            // introduced the Loader indirection).
            anchors.fill: parent
            spacing: StyleKit.Units.smallSpacing

            // Claims whatever space is left over after the (optional) Label
            // below takes its own natural height -- the icon/thumbnail below
            // is then sized to this Item's smaller dimension (see
            // resolvedIconSize), so it grows or shrinks automatically
            // with FileTile's own width/height instead of every caller
            // computing a matching size itself. ExplorerGrid.qml and
            // CollectionsView.qml both used to duplicate near-identical
            // cellWidth-based iconSize math for this; letting FileTile figure
            // it out from its own actual layout means a caller's cell-sizing
            // knobs (Explorer's iconScale, Collections' gridIconScale/
            // gridAspectRatio) just work without a second, parallel icon-size
            // formula that has to be kept in sync by hand.
            Item {
                id: iconArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property int resolvedIconSize: Math.max(0, Math.floor(Math.min(iconArea.width, iconArea.height)))

                // Shown whenever there's no (attempted or successful)
                // thumbnail -- directories always, files until/unless
                // their thumbnail finishes loading.
                Origami.Icon {
                    anchors.centerIn: parent
                    width: iconArea.resolvedIconSize
                    height: iconArea.resolvedIconSize
                    visible: root.isDir || thumbnail.status !== Image.Ready
                    source: root.iconName
                    color: root.colors.textColor
                }

                Image {
                    id: thumbnail
                    anchors.fill: parent
                    visible: !root.isDir && status === Image.Ready
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    source: root.isDir ? "" : root.thumbnailSource
                    sourceSize.width: iconArea.resolvedIconSize
                    sourceSize.height: iconArea.resolvedIconSize
                }

                // Symlink badge, Dolphin-style: Icon has no emblem/overlay
                // support of its own, so this is a second, smaller Icon
                // pinned to the visible icon's own bottom-right corner --
                // positioned relative to iconArea's center ± half of
                // resolvedIconSize (not parent.right/bottom directly), since
                // iconArea itself can be wider or taller than the square icon
                // actually drawn inside it.
                Origami.Icon {
                    visible: root.isSymlink
                    width: iconArea.resolvedIconSize * 0.5
                    height: iconArea.resolvedIconSize * 0.5
                    x: iconArea.width / 2 + iconArea.resolvedIconSize / 2 - width
                    y: iconArea.height / 2 + iconArea.resolvedIconSize / 2 - height
                    source: root.isBrokenSymlink ? "emblem-warning" : "emblem-symbolic-link"
                    color: root.isBrokenSymlink ? root.colors.negativeTextColor : root.colors.textColor
                }
            }

            Origami.Label {
                visible: root.showLabel
                text: root.text
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                // Middle (not right) elision: wraps up to 2 lines, and once a
                // name still doesn't fit past that, drops characters out of
                // the middle of the *last* line rather than the tail -- for a
                // typical "name.ext" file this leaves the extension (and a
                // few characters before it) visible instead of always cutting
                // it off, matching the common file-manager convention (Explorer/
                // Finder/Dolphin all keep the extension visible on truncation).
                elide: Text.ElideMiddle
            }
        }
    }

    // Drag proxy: a detached 1x1 Item (deliberately not `root` itself) is
    // what MouseArea.drag.target actually moves and what the Drag-attached
    // properties live on. Kept separate from `root` because `root`'s own
    // x/y are already owned by whichever GridView/ListView positions this
    // delegate -- letting drag.target write to those too would fight that
    // layout. `Drag.dragType: Automatic` is what makes Qt invoke a real
    // OS-level QDrag::exec() once the press-drag exceeds the threshold --
    // the standard, documented mechanism for dragging out of a QtQuick
    // app (confirmed via qquickdrag_p.h), distinct from DragHandler, which
    // never leaves the local scene.
    Item {
        id: dragProxy
        width: 1
        height: 1
        Drag.active: tapArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.mimeData: root.dragMimeData
        // The grabToImage snapshot (see root._dragImage's own comment)
        // and the exact point within it that was pressed, so the image
        // stays pinned under the cursor at wherever it was actually
        // "grabbed" rather than, say, always trailing from its top-left
        // corner. Deliberately NOT setting imageSourceSize (Qt 6.8+):
        // QQuickDragAttachedPrivate::loadPixmap() always forwards it
        // straight through as QQuickPixmap::load()'s requestSize, and for
        // a grabToImage:// source that Qt-side loader warns ("Ignoring
        // sourceSize request...") on ANY non-empty requestSize -- it never
        // compares against the image's actual size, so setting
        // imageSourceSize (even to a value matching the grab's own
        // targetSize) guarantees the warning on every drag rather than
        // avoiding it. Leaving it unset makes the getter fall back to the
        // already-loaded pixmap's own natural size once loaded (an
        // invalid/empty size before that, which the Qt-side check above
        // treats as "no request" and stays silent for) -- which already
        // equals Qt.size(root.width, root.height), the same targetSize
        // grabToImage below was called with, so the displayed drag image
        // is unaffected either way.
        Drag.imageSource: root._dragImage
        Drag.hotSpot.x: root._dragHotSpotX
        Drag.hotSpot.y: root._dragHotSpotY
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        // Right button accepted too, for contextMenuRequested below --
        // everything else in this MouseArea (drag-start, tapped()) stays
        // gated to a left-button press specifically (see leftPressed), so
        // a right-click can never also kick off a file drag.
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // A child item's own accepted press is hit-tested before the
        // parent Control (this ItemDelegate/AbstractButton) ever sees it
        // -- ordinary QtQuick propagation, safe to reason about without a
        // live GUI (unlike layering a TapHandler on the very same item as
        // AbstractButton's own built-in event handling, which Qt6 docs
        // flag as order-dependent/unreliable, and which was considered
        // and rejected for exactly that reason -- see this crate's own
        // TASKS.md entry for the full reasoning). This means
        // AbstractButton's own hovered/down no longer update from real
        // presses -- down's use above is replaced by this MouseArea's own
        // pressed; hovered still works, since hover propagation is
        // separate from press-acceptance and this MouseArea never sets
        // hoverEnabled.
        // Suppressed on a Shift-held press -- a caller wiring dragEnabled
        // together with tapped()'s own modifiers (ExplorerGrid.qml routes
        // Shift+tapped to a range-select) always means Shift+click there
        // is "range-select to here", never "drag this tile out", so an
        // OS-level drag-out must never start from it -- even if the
        // shift-click's own press+release happens to move a pixel or two
        // before release. shiftHeld is a plain property (not folded
        // directly into an imperative drag.target assignment in onPressed
        // below) so this stays a live binding, reacting to dragEnabled
        // itself changing too, not just frozen at whatever it was on the
        // last press.
        property bool shiftHeld: false
        // Tracks whether the current press started with the left button
        // -- drag.target below only activates for a left-button
        // press-drag; without this a right-click-and-drag could also
        // kick off the same OS-level file drag a left-drag does, which
        // isn't what a right click means anywhere else in this app (or
        // any desktop file manager).
        property bool leftPressed: false
        drag.target: (root.dragEnabled && !shiftHeld && leftPressed) ? dragProxy : null
        onPressed: mouse => {
            leftPressed = mouse.button === Qt.LeftButton;
            if (!leftPressed)
                return;
            shiftHeld = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            if (root.dragEnabled && !shiftHeld) {
                root._dragHotSpotX = mouse.x;
                root._dragHotSpotY = mouse.y;
                // Clearing _dragImage first (rather than just overwriting
                // it once the grab below resolves) matters beyond the
                // first-ever drag: Drag.imageSource: root._dragImage
                // (below) means this assignment synchronously calls
                // QQuickDragAttached::setImageSource(""), which clears
                // QQuickDragAttachedPrivate's internal pixmapLoader --
                // confirmed via Qt's own qquickdrag.cpp. Without this,
                // that pixmapLoader still holds the *previous* drag's
                // loaded pixmap, and imageSourceSize()'s fallback (used
                // internally to size the next load, since this file
                // deliberately never sets Drag.imageSourceSize itself --
                // see the dragProxy Item below) reads that stale, nonzero
                // width/height instead of 0 -- which is exactly what
                // re-triggers the "Ignoring sourceSize request" warning
                // from the second drag onward, even though the first
                // drag of the app's lifetime stays silent.
                root._dragImage = "";
                // targetSize pins the grab's own resolution up front --
                // a grabToImage result is a fixed-resolution image:// URL
                // that can't be resized afterward; leaving this unset and
                // relying on some later sourceSize binding to scale it
                // (e.g. whatever Qt Quick's own Drag.imageSource pixmap
                // rendering does internally) just gets silently ignored
                // with a console warning instead.
                root.grabToImage(function (result) {
                    root._dragImage = result.url;
                }, Qt.size(root.width, root.height));
            }
        }
        onReleased: leftPressed = false
        onCanceled: leftPressed = false
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.contextMenuRequested(mouse.x, mouse.y);
                return;
            }
            root.clicked();
            root.tapped(mouse.modifiers);
        }
    }
}
