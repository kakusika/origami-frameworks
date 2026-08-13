import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window
import la.cettila.Origami 1.0

// Leaf-only counterpart to ThemedMenu.qml.
QQC2.Menu {
    id: root

    property var menuItems: []
    readonly property var colors: Theme.paletteFor(Theme.header)

    cascade: true
    modal: false
    dim: false
    padding: Units.smallSpacing

    property bool detachedWindow: false
    popupType: detachedWindow ? QQC2.Popup.Window : QQC2.Popup.Item

    background: Rectangle {
        color: root.colors.backgroundColor
        radius: Units.cornerRadius > 0 ? Units.cornerRadius + root.padding : 0
        border.width: Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3)
    }

    contentItem: ListView {
        implicitHeight: contentHeight
        implicitWidth: contentItem.visibleChildren.reduce((maxWidth, child) => Math.max(maxWidth, child.implicitWidth), 0)
        model: root.contentModel
        interactive: Window.window ? contentHeight + root.topPadding + root.bottomPadding > root.height : false
        clip: true

        QQC2.ScrollIndicator.vertical: QQC2.ScrollIndicator {}
    }

    Repeater {
        model: root.menuItems

        delegate: QQC2.MenuItem {
            id: menuItem
            required property var modelData
            text: (typeof modelData === "string") ? modelData : modelData.text
            readonly property bool _selected: (typeof modelData === "string") ? false : (modelData.selected === true)
            enabled: (typeof modelData === "string") ? true : (modelData.enabled !== false) && !menuItem._selected

            readonly property string _iconName: (typeof modelData === "string") ? "" : (modelData.icon || "")

            background: Rectangle {
                radius: Units.cornerRadius
                color: (menuItem.highlighted || menuItem._selected) ? root.colors.highlightColor : "transparent"
            }

            contentItem: Row {
                spacing: Units.smallSpacing
                leftPadding: Units.smallSpacing
                rightPadding: Units.smallSpacing

                Icon {
                    visible: menuItem._iconName !== ""
                    color: root.colors.textColor
                    source: menuItem._iconName
                    width: Units.iconSizes.small
                    height: Units.iconSizes.small
                }

                Text {
                    text: menuItem.text
                    verticalAlignment: Text.AlignVCenter
                    color: menuItem._selected ? root.colors.highlightedTextColor : (!menuItem.enabled ? Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.4) : (menuItem.highlighted ? root.colors.highlightedTextColor : root.colors.textColor))
                }
            }

            onTriggered: {
                if (modelData && modelData.onTriggered)
                    modelData.onTriggered();
            }
        }
    }
}
