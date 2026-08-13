import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window
import la.cettila.App 1.0
import la.cettila.Origami 1.0 as Origami

QQC2.ApplicationWindow {
    id: window
    visible: true
    width: 1080
    height: 760
    minimumWidth: 720
    minimumHeight: 520
    title: "Origami & QQC2 Component Gallery"

    header: QQC2.ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Origami.Label {
                text: "Component Gallery"
                font.bold: true
                font.pixelSize: 16
            }

            Item {
                Layout.preferredWidth: 24
            }

            QQC2.TabBar {
                id: mainTabBar
                Layout.preferredWidth: 320

                QQC2.TabButton {
                    text: "Origami Widgets"
                }
                QQC2.TabButton {
                    text: "QQC2 Widgets"
                }
                QQC2.TabButton {
                    text: "Ayame Widgets"
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: mainTabBar.currentIndex

        OrigamiWidgetsPage {
            id: origamiPage
        }

        QQC2WidgetsPage {
            id: qqc2Page
        }

        AyameWidgetsPage {
            id: ayamePage
        }
    }

    // Global Toast Notification listener overlay
    Origami.ToastNotification {
        id: globalToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
    }
}
