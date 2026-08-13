import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

// Clickable path breadcrumb: splits `path` into segments and renders one
// button per segment, each jumping straight to that ancestor directory
// when clicked. Extracted from ImagePickerPage.qml (originally
// unrestricted, rootPath left "") so cettila-view-explorer's
// ExplorerGrid.qml could reuse it too, clamped to the vault root via
// `rootPath` -- a segment above that never appears, matching
// ExplorerGridModel's own "never navigate above DEFAULT_ROOT" rule.
Item {
    id: root

    property string path: ""

    // Segments above this path are omitted; its own last path component
    // becomes the leftmost breadcrumb entry instead of "/". Left "" (the
    // default) to show the full path from the filesystem root.
    property string rootPath: ""

    // Emitted with the absolute path a segment click should jump to.
    // Callers wire this to whatever their model's navigation call is
    // (ImagePickerModel/ExplorerGridModel's navigateTo).
    signal navigated(string path)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property var colors: Theme.paletteFor(Theme.view)

    // The visible root's label + every path component below it, each
    // carrying the absolute path clicking it should jump to. E.g. with
    // rootPath "/home/user" and path "/home/user/Pictures/2024": ->
    // [{label:"user", path:"/home/user"}, {label:"Pictures",
    // path:"/home/user/Pictures"}, {label:"2024",
    // path:"/home/user/Pictures/2024"}].
    readonly property var segments: {
        var relevant = root.path;
        var prefix = "";
        if (root.rootPath.length > 0 && relevant.indexOf(root.rootPath) === 0) {
            prefix = root.rootPath;
            relevant = relevant.slice(root.rootPath.length);
        }

        var rootParts = prefix.split("/").filter(p => p.length > 0);
        var startLabel = rootParts.length > 0 ? rootParts[rootParts.length - 1] : "/";
        var result = [
            {
                label: startLabel,
                path: prefix.length > 0 ? prefix : "/"
            }
        ];

        var accumulated = prefix;
        var parts = relevant.split("/").filter(p => p.length > 0);
        for (var i = 0; i < parts.length; i++) {
            accumulated += "/" + parts[i];
            result.push({
                label: parts[i],
                path: accumulated
            });
        }
        return result;
    }

    Flickable {
        anchors.fill: parent
        contentWidth: row.implicitWidth
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        RowLayout {
            id: row
            spacing: 0

            Repeater {
                model: root.segments

                delegate: RowLayout {
                    spacing: 0

                    QQC2.ToolButton {
                        id: segmentButton
                        text: modelData.label

                        contentItem: Text {
                            anchors.centerIn: parent
                            text: segmentButton.text
                            color: root.colors.textColor
                        }

                        onClicked: root.navigated(modelData.path)
                    }

                    Label {
                        text: "/"
                        visible: index < root.segments.length - 1
                    }
                }
            }
        }
    }
}
