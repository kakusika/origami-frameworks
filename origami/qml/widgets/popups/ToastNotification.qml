import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0

// Floating toast overlay item. Listens to ToastBus and displays smooth transient messages.
Item {
    id: root

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: Units.largeSpacing * 2
    z: 9999

    property string message: ""
    property string iconName: "dialog-information-symbolic"
    property string toastType: "info"
    property bool showing: false

    readonly property var colors: Theme.paletteFor(Theme.tooltip)

    Connections {
        target: ToastBus
        function onShowToast(msg, icon, type, durationMs) {
            root.message = msg;
            root.iconName = icon;
            root.toastType = type;
            root.showing = true;
            hideTimer.interval = durationMs;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.showing = false
    }

    Rectangle {
        id: banner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        implicitWidth: layout.implicitWidth + Units.largeSpacing * 2
        implicitHeight: Units.gridUnit * 2
        radius: Units.cornerRadius
        color: root.colors.backgroundColor
        border.width: Units.borderWidth
        border.color: {
            if (root.toastType === "success")
                return root.colors.positiveTextColor;
            if (root.toastType === "negative")
                return root.colors.negativeTextColor;
            return Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.3);
        }

        opacity: root.showing ? 0.95 : 0.0
        scale: root.showing ? 1.0 : 0.9

        Behavior on opacity {
            NumberAnimation {
                duration: Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Units.shortDuration
                easing.type: Easing.OutBack
            }
        }

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.leftMargin: Units.largeSpacing
            anchors.rightMargin: Units.largeSpacing
            spacing: Units.smallSpacing

            Icon {
                source: root.iconName
                width: Units.iconSizes.small
                height: Units.iconSizes.small
                color: root.colors.textColor
            }

            Label {
                text: root.message
                colorSet: Theme.tooltip
            }

            IconButton {
                iconName: "window-close-symbolic"
                onClicked: root.showing = false
            }
        }
    }
}
