import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Single on/off icon toggle with optional details popup button.
Item {
    id: root

    property string iconName: ""
    property bool checked: false
    readonly property alias hovered: toggleButton.hovered

    signal toggled(bool checked)

    property Item detailsContent: null
    readonly property bool hasDetails: root.detailsContent !== null
    readonly property var colors: Theme.paletteFor(Theme.header)

    implicitWidth: row.implicitWidth
    implicitHeight: Units.gridUnit * 1.6

    Rectangle {
        anchors.fill: parent
        radius: Units.cornerRadius
        color: "transparent"
        border.width: Units.borderWidth
        border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3)
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 0

        QQC2.ToolButton {
            id: toggleButton
            implicitWidth: Units.iconSizes.smallMedium + Units.largeSpacing
            height: root.height

            contentItem: Icon {
                anchors.centerIn: parent
                color: root.checked ? root.colors.highlightedTextColor : root.colors.textColor
                source: root.iconName
                width: Units.iconSizes.smallMedium
                height: Units.iconSizes.smallMedium
            }

            background: Rectangle {
                topLeftRadius: Units.cornerRadius
                bottomLeftRadius: Units.cornerRadius
                topRightRadius: root.hasDetails ? 0 : Units.cornerRadius
                bottomRightRadius: root.hasDetails ? 0 : Units.cornerRadius
                color: root.checked ? root.colors.highlightColor : (toggleButton.hovered ? root.colors.hoverColor : "transparent")
            }

            onClicked: root.toggled(!root.checked)
        }

        QQC2.ToolButton {
            id: detailsButton
            visible: root.hasDetails
            implicitWidth: Units.iconSizes.small + Units.smallSpacing * 2
            height: root.height

            contentItem: Icon {
                anchors.centerIn: parent
                color: root.colors.textColor
                source: "arrow-down-symbolic"
                width: Units.iconSizes.small
                height: Units.iconSizes.small
            }

            background: Rectangle {
                topRightRadius: Units.cornerRadius
                bottomRightRadius: Units.cornerRadius
                color: detailsPopup.visible ? root.colors.highlightColor : (detailsButton.hovered ? root.colors.hoverColor : "transparent")

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
                }
            }

            onClicked: detailsPopup.open()

            QQC2.Popup {
                id: detailsPopup
                parent: detailsButton
                closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
                x: detailsButton.width - width
                y: detailsButton.height + Units.smallSpacing

                onOpened: {
                    if (root.detailsContent) {
                        root.detailsContent.parent = detailsPopup.contentItem;
                        root.detailsContent.anchors.fill = detailsPopup.contentItem;
                        root.detailsContent.visible = true;
                    }
                }

                contentItem: Item {
                    implicitWidth: root.detailsContent ? root.detailsContent.implicitWidth : Units.gridUnit * 10
                    implicitHeight: root.detailsContent ? root.detailsContent.implicitHeight : Units.gridUnit * 6
                }
            }
        }
    }
}
