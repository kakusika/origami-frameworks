import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Floating toast overlay item. Listens to ToastBus and displays smooth transient messages.
Item {
    id: root

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.bottomMargin: StyleKit.Units.largeSpacing * 2
    z: 9999

    property string message: ""
    property string iconName: "dialog-information-symbolic"
    property string toastType: "info"
    property bool showing: false

    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.tooltip)

    Connections {
        target: Origami.ToastBus
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
        implicitWidth: layout.implicitWidth + StyleKit.Units.largeSpacing * 2
        implicitHeight: StyleKit.Units.gridUnit * 2
        radius: StyleKit.Units.cornerRadius
        color: root.colors.backgroundColor
        border.width: StyleKit.Units.borderWidth
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
                duration: StyleKit.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: StyleKit.Units.shortDuration
                easing.type: Easing.OutBack
            }
        }

        RowLayout {
            id: layout
            anchors.fill: parent
            anchors.leftMargin: StyleKit.Units.largeSpacing
            anchors.rightMargin: StyleKit.Units.largeSpacing
            spacing: StyleKit.Units.smallSpacing

            Origami.Icon {
                source: root.iconName
                width: StyleKit.Units.iconSizes.small
                height: StyleKit.Units.iconSizes.small
                color: root.colors.textColor
            }

            Origami.Label {
                text: root.message
                colorSet: StyleKit.Theme.tooltip
            }

            Origami.IconButton {
                iconName: "window-close-symbolic"
                onClicked: root.showing = false
            }
        }
    }
}
