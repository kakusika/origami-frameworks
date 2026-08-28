import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Single on/off icon toggle with optional details popup button.
Item {
    id: root

    property string iconName: ""
    property bool checked: false
    readonly property alias hovered: toggleButton.hovered

    signal toggled(bool checked)

    property Item detailsContent: null
    readonly property bool hasDetails: root.detailsContent !== null
    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.header)

    implicitWidth: row.implicitWidth
    implicitHeight: StyleKit.Units.gridUnit * 1.6

    Rectangle {
        anchors.fill: parent
        radius: StyleKit.Units.cornerRadius
        color: "transparent"
        border.width: StyleKit.Units.borderWidth
        border.color: root.colors.borderColor
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 0

        QQC2.ToolButton {
            id: toggleButton
            implicitWidth: StyleKit.Units.iconSizes.smallMedium + StyleKit.Units.largeSpacing
            height: root.height

            contentItem: Origami.Icon {
                anchors.centerIn: parent
                color: root.checked ? root.colors.highlightedTextColor : root.colors.textColor
                source: root.iconName
                width: StyleKit.Units.iconSizes.smallMedium
                height: StyleKit.Units.iconSizes.smallMedium
            }

            background: Rectangle {
                topLeftRadius: StyleKit.Units.cornerRadius
                bottomLeftRadius: StyleKit.Units.cornerRadius
                topRightRadius: root.hasDetails ? 0 : StyleKit.Units.cornerRadius
                bottomRightRadius: root.hasDetails ? 0 : StyleKit.Units.cornerRadius
                color: root.checked ? root.colors.highlightColor : (toggleButton.hovered ? root.colors.hoverColor : "transparent")
            }

            onClicked: root.toggled(!root.checked)
        }

        QQC2.ToolButton {
            id: detailsButton
            visible: root.hasDetails
            implicitWidth: StyleKit.Units.iconSizes.small + StyleKit.Units.smallSpacing * 2
            height: root.height

            contentItem: Origami.Icon {
                anchors.centerIn: parent
                color: root.colors.textColor
                source: "arrow-down-symbolic"
                width: StyleKit.Units.iconSizes.small
                height: StyleKit.Units.iconSizes.small
            }

            background: Rectangle {
                topRightRadius: StyleKit.Units.cornerRadius
                bottomRightRadius: StyleKit.Units.cornerRadius
                color: detailsPopup.visible ? root.colors.highlightColor : (detailsButton.hovered ? root.colors.hoverColor : "transparent")

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: StyleKit.Theme.opaqueBlend(root.colors.textColor, root.colors.backgroundColor, 0.2)
                }
            }

            onClicked: detailsPopup.open()

            QQC2.Popup {
                id: detailsPopup
                parent: detailsButton
                closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
                x: detailsButton.width - width
                y: detailsButton.height + StyleKit.Units.smallSpacing

                onOpened: {
                    if (root.detailsContent) {
                        root.detailsContent.parent = detailsPopup.contentItem;
                        root.detailsContent.anchors.fill = detailsPopup.contentItem;
                        root.detailsContent.visible = true;
                    }
                }

                contentItem: Item {
                    implicitWidth: root.detailsContent ? root.detailsContent.implicitWidth : StyleKit.Units.gridUnit * 10
                    implicitHeight: root.detailsContent ? root.detailsContent.implicitHeight : StyleKit.Units.gridUnit * 6
                }
            }
        }
    }
}
