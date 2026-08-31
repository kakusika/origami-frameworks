import QtQuick
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// A categorized sidebar for a Settings-style page: an icon+label list on
// the left (selectable, hover/selection highlight) plus an optional
// caller-supplied footer pinned below it. Extracted from cettila's own
// SettingsPage.qml, which used to hand-roll this exact shell inline
// (see that file's own class comment for how the two now fit together) --
// everything about the actual settings *content* (the category pages
// themselves, dirty-tracking, persistence, restart-to-apply) stays
// entirely app-specific and isn't part of this component at all. This is
// the one piece of that page that was actually generic.
Rectangle {
    id: root

    // Each entry: {text, icon}. Tapping a row only ever updates
    // currentIndex -- switching the content shown for it is the caller's
    // own job (typically a same-indexed ScrollView/Column elsewhere,
    // gated by `visible: currentIndex === N`, same as the original page).
    property var categories: []
    property int currentIndex: 0

    // Optional element pinned below the category list, e.g. a
    // restart-to-apply button for an app whose settings model needs one --
    // left null for a caller with nothing to put there, in which case the
    // category list simply extends to the bottom margin instead.
    property Component footer: null

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.view)

    implicitWidth: StyleKit.Units.gridUnit * 9
    color: root.colors.backgroundColor

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
    }

    Column {
        id: categoryColumn
        anchors.top: parent.top
        anchors.bottom: footerLoader.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: StyleKit.Units.smallSpacing
        spacing: StyleKit.Units.smallSpacing / 2

        Repeater {
            model: root.categories

            delegate: Rectangle {
                id: categoryRow
                required property var modelData
                required property int index

                readonly property bool selected: categoryRow.index === root.currentIndex

                width: categoryColumn.width
                height: StyleKit.Units.gridUnit * 1.8
                radius: StyleKit.Units.cornerRadius
                color: categoryRow.selected ? root.colors.highlightColor : (rowHover.hovered ? root.colors.hoverColor : "transparent")

                HoverHandler {
                    id: rowHover
                }

                TapHandler {
                    onTapped: root.currentIndex = categoryRow.index
                }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: StyleKit.Units.smallSpacing
                    spacing: StyleKit.Units.smallSpacing

                    Origami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: categoryRow.modelData.icon
                        width: StyleKit.Units.iconSizes.small
                        height: StyleKit.Units.iconSizes.small
                        color: categoryRow.selected ? root.colors.highlightedTextColor : root.colors.textColor
                    }

                    Origami.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: categoryRow.modelData.text
                        color: categoryRow.selected ? root.colors.highlightedTextColor : root.colors.textColor
                    }
                }
            }
        }
    }

    // Sized to 0 (Loader's own default with no active item) when `footer`
    // is left unset, so categoryColumn's own anchors.bottom above just
    // extends to this Item's top -- effectively the bottom margin -- with
    // no gap left behind for an absent footer.
    Loader {
        id: footerLoader
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: StyleKit.Units.smallSpacing
        sourceComponent: root.footer
        // Loader's own implicitHeight is a read-only property it computes
        // from the loaded item itself -- bind height straight to that
        // instead of trying to assign it (item is null, and this height
        // 0, whenever `footer` is unset).
        height: item ? item.implicitHeight : 0
    }
}
