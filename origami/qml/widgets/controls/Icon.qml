import QtQuick
import QtQuick.Controls.impl as CI

// Composition, not inheritance: CI.IconImage already has a `source`
// (url) property, and this component's own public `source` means a
// freedesktop-style icon *name* (`Icon { source: "document-new" }`,
// matching every existing call site) -- those are two different
// things that can't share one property name on the same object, so
// the name -> resource-path resolution below needs a separate child
// object to write the real `source` url into.
Item {
    id: root

    property string source: ""
    property alias color: image.color
    property alias sourceSize: image.sourceSize

    width: 16
    height: 16

    CI.IconImage {
        id: image
        anchors.fill: parent

        // Resolve against the Tabler Icons bundled with ayame-icons
        // (qrc:/cettila/icons/<name>.svg -- see ayame/crates/icons and
        // ayame/.agents/tasks/bundle-tabler-icons.md) instead of OS
        // icon-theme resolution, so rendering is byte-identical
        // regardless of QQC2 style or desktop icon theme.
        //
        // `name` is deliberately left unset: QQuickIconImage resolves
        // via `name`/QIcon::fromTheme whenever `name` is non-empty,
        // taking priority over `source` regardless of whether `source`
        // is also set -- binding both (as an earlier version of this
        // file did) meant `source` was silently never used and every
        // icon kept rendering through the OS theme (Breeze) instead of
        // the bundled set. An icon name without a corresponding entry
        // in ayame-icons' mapping now renders blank rather than
        // falling back to the theme -- consistent with removing
        // crates/qml6/cpp/icon_theme.cpp's theme-fallback stopgap.
        source: root.source.length > 0 ? "qrc:/cettila/icons/" + root.source + ".svg" : ""
        sourceSize.width: image.width
        sourceSize.height: image.height
    }
}
