import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami

QQC2.ScrollView {
    id: root
    contentWidth: availableWidth
    clip: true

    property real sliderVal: 50
    property int spinVal: 25

    ColumnLayout {
        width: parent.width - 40
        spacing: 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        anchors.bottomMargin: 40

        // Title Header
        ColumnLayout {
            spacing: 4
            QQC2.Label {
                text: "Ayame Widgets Catalog"
                font.pixelSize: 22
                font.bold: true
            }
            QQC2.Label {
                text: "Full QQC2 native theme controls library (Ayame 1.0)"
                opacity: 0.7
            }
        }

        // ---------------------------------------------------------
        // Section 1: Buttons & Toggles
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "1. Buttons & Toggles"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                RowLayout {
                    spacing: 12

                    QQC2.Button {
                        text: "Standard Button"
                        onClicked: Origami.ToastBus.info("Ayame Button Clicked")
                    }
                    QQC2.Button {
                        text: "Highlighted"
                        highlighted: true
                        onClicked: Origami.ToastBus.success("Highlighted Action")
                    }
                    QQC2.Button {
                        text: "Flat Button"
                        flat: true
                    }
                    QQC2.Button {
                        text: "Disabled"
                        enabled: false
                    }
                }

                RowLayout {
                    spacing: 16

                    QQC2.RoundButton {
                        text: "+"
                        onClicked: Origami.ToastBus.info("RoundButton +")
                    }
                    QQC2.RoundButton {
                        text: "-"
                        onClicked: Origami.ToastBus.info("RoundButton -")
                    }
                    QQC2.ToolButton {
                        text: "ToolButton"
                        onClicked: Origami.ToastBus.info("ToolButton Clicked")
                    }
                    QQC2.DelayButton {
                        text: "Hold to Confirm"
                        delay: 1000
                        onActivated: Origami.ToastBus.warning("DelayButton Activated!")
                    }
                }

                QQC2.ToolSeparator {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 32

                    ColumnLayout {
                        spacing: 6
                        QQC2.CheckBox {
                            text: "CheckBox (Checked)"
                            checked: true
                        }
                        QQC2.CheckBox {
                            text: "CheckBox (Unchecked)"
                            checked: false
                        }
                        QQC2.CheckBox {
                            text: "CheckBox (Tristate)"
                            tristate: true
                            checkState: Qt.PartiallyChecked
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        QQC2.ButtonGroup {
                            id: ayameRadioGroup
                        }
                        QQC2.RadioButton {
                            text: "Option 1"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                            checked: true
                        }
                        QQC2.RadioButton {
                            text: "Option 2"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                        }
                        QQC2.RadioButton {
                            text: "Option 3"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        QQC2.Switch {
                            id: sampleSwitch
                            text: sampleSwitch.checked ? "Switch: ON" : "Switch: OFF"
                            checked: true
                        }
                        QQC2.Switch {
                            text: "Disabled Switch"
                            enabled: false
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 2: Input Fields
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "2. Input Fields & Selection"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                RowLayout {
                    spacing: 16
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 4
                        QQC2.Label {
                            text: "TextField:"
                            font.bold: true
                        }
                        QQC2.TextField {
                            id: sampleTextField
                            placeholderText: "Type text here..."
                            Layout.preferredWidth: 200
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        QQC2.Label {
                            text: "SpinBox:"
                            font.bold: true
                        }
                        QQC2.SpinBox {
                            from: 0
                            to: 100
                            value: root.spinVal
                            editable: true
                            onValueChanged: root.spinVal = value
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        QQC2.Label {
                            text: "ComboBox:"
                            font.bold: true
                        }
                        QQC2.ComboBox {
                            model: ["Option Alpha", "Option Beta", "Option Gamma", "Option Delta"]
                        }
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    QQC2.Label {
                        text: "TextArea (Scrollable):"
                        font.bold: true
                    }
                    QQC2.ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 80
                        QQC2.TextArea {
                            placeholderText: "Multi-line text editor...\nType longer content here."
                            text: "Echo: " + sampleTextField.text
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 3: Sliders, Dials & Indicators
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "3. Sliders, Dials & Indicators"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                RowLayout {
                    spacing: 24
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        QQC2.Label {
                            text: "Slider (Value: " + Math.round(ayameSlider.value) + ")"
                        }
                        QQC2.Slider {
                            id: ayameSlider
                            from: 0
                            to: 100
                            value: root.sliderVal
                            Layout.fillWidth: true
                            onValueChanged: root.sliderVal = value
                        }

                        QQC2.Label {
                            text: "ProgressBar (Determinate)"
                        }
                        QQC2.ProgressBar {
                            from: 0
                            to: 100
                            value: ayameSlider.value
                            Layout.fillWidth: true
                        }

                        QQC2.Label {
                            text: "ProgressBar (Indeterminate)"
                        }
                        QQC2.ProgressBar {
                            indeterminate: true
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        QQC2.Label {
                            text: "Dial"
                        }
                        QQC2.Dial {
                            id: ayameDial
                            from: 0
                            to: 100
                            value: ayameSlider.value
                            onValueChanged: ayameSlider.value = value
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        QQC2.Label {
                            text: "BusyIndicator"
                        }
                        QQC2.BusyIndicator {
                            running: busySwitch.checked
                        }
                        QQC2.Switch {
                            id: busySwitch
                            text: "Running"
                            checked: true
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    QQC2.Label {
                        text: "RangeSlider (First: " + Math.round(ayameRangeSlider.first.value) + ", Second: " + Math.round(ayameRangeSlider.second.value) + ")"
                    }
                    QQC2.RangeSlider {
                        id: ayameRangeSlider
                        from: 0
                        to: 100
                        first.value: 20
                        second.value: 80
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: 32
                    Layout.fillWidth: true

                    ColumnLayout {
                        spacing: 8
                        QQC2.Label {
                            text: "PageIndicator:"
                        }
                        QQC2.PageIndicator {
                            count: 5
                            currentIndex: 2
                        }
                    }

                    ColumnLayout {
                        spacing: 8
                        QQC2.Label {
                            text: "Tumbler (Wheel):"
                        }
                        QQC2.Tumbler {
                            model: 10
                            visibleItemCount: 3
                            implicitHeight: 80
                            implicitWidth: 60
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 4: Delegates
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "4. Delegates (Item, Check, Radio, Switch, Swipe)"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 8

                QQC2.Frame {
                    Layout.fillWidth: true
                    padding: 0

                    ColumnLayout {
                        width: parent.width
                        spacing: 0

                        QQC2.ItemDelegate {
                            text: "ItemDelegate (Standard)"
                            Layout.fillWidth: true
                            onClicked: Origami.ToastBus.info("Clicked ItemDelegate")
                        }

                        QQC2.CheckDelegate {
                            text: "CheckDelegate (Checked)"
                            checked: true
                            Layout.fillWidth: true
                        }

                        QQC2.RadioDelegate {
                            text: "RadioDelegate (Option)"
                            checked: false
                            Layout.fillWidth: true
                        }

                        QQC2.SwitchDelegate {
                            text: "SwitchDelegate (Toggle)"
                            checked: true
                            Layout.fillWidth: true
                        }

                        QQC2.SwipeDelegate {
                            text: "SwipeDelegate (Swipeable)"
                            Layout.fillWidth: true
                            swipe.right: Rectangle {
                                width: 100
                                height: parent.height
                                color: "#ef4444"
                                QQC2.Label {
                                    anchors.centerIn: parent
                                    text: "Delete"
                                    color: "white"
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 5: Containers, TabBars & Popups
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "5. Navigation, TabBars & Dialogs"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                QQC2.TabBar {
                    id: ayameTabBar
                    Layout.fillWidth: true

                    QQC2.TabButton {
                        text: "Tab Overview"
                    }
                    QQC2.TabButton {
                        text: "Tab Details"
                    }
                    QQC2.TabButton {
                        text: "Tab Settings"
                    }
                }

                StackLayout {
                    currentIndex: ayameTabBar.currentIndex
                    Layout.fillWidth: true
                    implicitHeight: 60

                    QQC2.Frame {
                        QQC2.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 1: Overview Panel"
                        }
                    }
                    QQC2.Frame {
                        QQC2.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 2: Details & Stats"
                        }
                    }
                    QQC2.Frame {
                        QQC2.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 3: Settings Panel"
                        }
                    }
                }

                RowLayout {
                    spacing: 16

                    QQC2.Button {
                        text: "Open Ayame Dialog"
                        highlighted: true
                        onClicked: ayameDialog.open()
                    }

                    QQC2.Button {
                        text: "Open Ayame Popup"
                        onClicked: ayamePopup.open()
                    }

                    QQC2.Button {
                        text: "Toggle Side Drawer"
                        onClicked: ayameDrawer.open()
                    }
                }
            }
        }
    }

    // Modal Ayame Dialog
    QQC2.Dialog {
        id: ayameDialog
        title: "Ayame Modal Dialog"
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        ColumnLayout {
            spacing: 12
            QQC2.Label {
                text: "This is a custom Ayame styled modal dialog."
            }
            QQC2.CheckBox {
                text: "Remember selection"
                checked: true
            }
        }
        onAccepted: Origami.ToastBus.success("Ayame Dialog Accepted")
    }

    // Ayame Popup
    QQC2.Popup {
        id: ayamePopup
        anchors.centerIn: parent
        width: 300
        height: 160
        modal: true
        focus: true
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

        ColumnLayout {
            anchors.fill: parent
            QQC2.Label {
                text: "Ayame Popup Window"
                font.bold: true
            }
            QQC2.Label {
                text: "Press Escape or click outside to dismiss."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            QQC2.Button {
                text: "Close"
                Layout.alignment: Qt.AlignRight
                onClicked: ayamePopup.close()
            }
        }
    }

    // Ayame Drawer
    QQC2.Drawer {
        id: ayameDrawer
        width: 250
        height: root.height
        edge: Qt.LeftEdge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            QQC2.Label {
                text: "Ayame Side Drawer"
                font.bold: true
                font.pixelSize: 18
            }

            QQC2.Label {
                text: "Slide-out navigation drawer panel."
                wrapMode: Text.WordWrap
            }

            QQC2.Button {
                text: "Close Drawer"
                onClicked: ayameDrawer.close()
            }
        }
    }
}
