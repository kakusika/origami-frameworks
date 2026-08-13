import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Segmented toggle control.
Item {
    id: root

    property var options: []
    property var value: null

    signal valueChangeRequested(var value)

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

    readonly property real _optionWidth: Units.iconSizes.smallMedium + Units.largeSpacing

    readonly property int _activeIndex: {
        for (let i = 0; i < root.options.length; i++) {
            if (root.options[i].value === root.value)
                return i;
        }
        return -1;
    }

    Rectangle {
        id: selectionIndicator
        visible: root._activeIndex >= 0
        x: root._activeIndex >= 0 ? root._activeIndex * root._optionWidth : 0
        width: root._optionWidth
        height: root.height
        topLeftRadius: root._activeIndex === 0 ? Units.cornerRadius : 0
        bottomLeftRadius: root._activeIndex === 0 ? Units.cornerRadius : 0
        topRightRadius: (!root.hasDetails && root._activeIndex === root.options.length - 1) ? Units.cornerRadius : 0
        bottomRightRadius: (!root.hasDetails && root._activeIndex === root.options.length - 1) ? Units.cornerRadius : 0
        color: root.colors.highlightColor

        Behavior on x {
            NumberAnimation {
                duration: 100
            }
        }
    }

    Row {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.options

            QQC2.ToolButton {
                id: optionButton
                required property var modelData
                required property int index

                readonly property bool isActive: root._activeIndex === optionButton.index

                implicitWidth: root._optionWidth
                height: root.height

                contentItem: Icon {
                    anchors.centerIn: parent
                    color: optionButton.isActive ? root.colors.highlightedTextColor : root.colors.textColor
                    source: optionButton.modelData.iconName || ""
                    width: Units.iconSizes.smallMedium
                    height: Units.iconSizes.smallMedium
                }

                background: Rectangle {
                    topLeftRadius: optionButton.index === 0 ? Units.cornerRadius : 0
                    bottomLeftRadius: optionButton.index === 0 ? Units.cornerRadius : 0
                    topRightRadius: (!root.hasDetails && optionButton.index === root.options.length - 1) ? Units.cornerRadius : 0
                    bottomRightRadius: (!root.hasDetails && optionButton.index === root.options.length - 1) ? Units.cornerRadius : 0
                    color: (optionButton.hovered && !optionButton.isActive) ? root.colors.hoverColor : "transparent"

                    Rectangle {
                        visible: optionButton.index > 0
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
                    }
                }

                onClicked: root.valueChangeRequested(optionButton.modelData.value)
            }
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
