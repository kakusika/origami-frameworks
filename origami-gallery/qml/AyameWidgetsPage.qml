import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Ayame as Ayame
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
            Ayame.Label {
                text: "Ayame Widgets Catalog"
                font.pixelSize: 22
                font.bold: true
            }
            Ayame.Label {
                text: "Full Ayame native theme controls library (Ayame 1.0)"
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

                    Ayame.Button {
                        text: "Standard Button"
                        onClicked: Origami.ToastBus.info("Ayame Button Clicked")
                    }
                    Ayame.Button {
                        text: "Highlighted"
                        highlighted: true
                        onClicked: Origami.ToastBus.success("Highlighted Action")
                    }
                    Ayame.Button {
                        text: "Flat Button"
                        flat: true
                    }
                    Ayame.Button {
                        text: "Disabled"
                        enabled: false
                    }
                }

                RowLayout {
                    spacing: 16

                    Ayame.RoundButton {
                        text: "+"
                        onClicked: Origami.ToastBus.info("RoundButton +")
                    }
                    Ayame.RoundButton {
                        text: "-"
                        onClicked: Origami.ToastBus.info("RoundButton -")
                    }
                    Ayame.ToolButton {
                        text: "ToolButton"
                        onClicked: Origami.ToastBus.info("ToolButton Clicked")
                    }
                    Ayame.DelayButton {
                        text: "Hold to Confirm"
                        delay: 1000
                        onActivated: Origami.ToastBus.warning("DelayButton Activated!")
                    }
                }

                Ayame.ToolSeparator {
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 32

                    ColumnLayout {
                        spacing: 6
                        Ayame.CheckBox {
                            text: "CheckBox (Checked)"
                            checked: true
                        }
                        Ayame.CheckBox {
                            text: "CheckBox (Unchecked)"
                            checked: false
                        }
                        Ayame.CheckBox {
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
                        Ayame.RadioButton {
                            text: "Option 1"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                            checked: true
                        }
                        Ayame.RadioButton {
                            text: "Option 2"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                        }
                        Ayame.RadioButton {
                            text: "Option 3"
                            QQC2.ButtonGroup.group: ayameRadioGroup
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        Ayame.Switch {
                            id: sampleSwitch
                            text: sampleSwitch.checked ? "Switch: ON" : "Switch: OFF"
                            checked: true
                        }
                        Ayame.Switch {
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
                        Ayame.Label {
                            text: "TextField:"
                            font.bold: true
                        }
                        Ayame.TextField {
                            id: sampleTextField
                            placeholderText: "Type text here..."
                            Layout.preferredWidth: 200
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Ayame.Label {
                            text: "SpinBox:"
                            font.bold: true
                        }
                        Ayame.SpinBox {
                            from: 0
                            to: 100
                            value: root.spinVal
                            editable: true
                            onValueChanged: root.spinVal = value
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Ayame.Label {
                            text: "ComboBox:"
                            font.bold: true
                        }
                        Ayame.ComboBox {
                            model: ["Option Alpha", "Option Beta", "Option Gamma", "Option Delta"]
                        }
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Ayame.Label {
                        text: "TextArea (Scrollable):"
                        font.bold: true
                    }
                    QQC2.ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 80
                        Ayame.TextArea {
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
                        Ayame.Label {
                            text: "Slider (Value: " + Math.round(ayameSlider.value) + ")"
                        }
                        Ayame.Slider {
                            id: ayameSlider
                            from: 0
                            to: 100
                            value: root.sliderVal
                            Layout.fillWidth: true
                            onValueChanged: root.sliderVal = value
                        }

                        Ayame.Label {
                            text: "ProgressBar (Determinate)"
                        }
                        Ayame.ProgressBar {
                            from: 0
                            to: 100
                            value: ayameSlider.value
                            Layout.fillWidth: true
                        }

                        Ayame.Label {
                            text: "ProgressBar (Indeterminate)"
                        }
                        Ayame.ProgressBar {
                            indeterminate: true
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Ayame.Label {
                            text: "Dial"
                        }
                        Ayame.Dial {
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
                        Ayame.Label {
                            text: "BusyIndicator"
                        }
                        Ayame.BusyIndicator {
                            running: busySwitch.checked
                        }
                        Ayame.Switch {
                            id: busySwitch
                            text: "Running"
                            checked: true
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Ayame.Label {
                        text: "RangeSlider (First: " + Math.round(ayameRangeSlider.first.value) + ", Second: " + Math.round(ayameRangeSlider.second.value) + ")"
                    }
                    Ayame.RangeSlider {
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
                        Ayame.Label {
                            text: "PageIndicator:"
                        }
                        Ayame.PageIndicator {
                            count: 5
                            currentIndex: 2
                        }
                    }

                    ColumnLayout {
                        spacing: 8
                        Ayame.Label {
                            text: "Tumbler (Wheel):"
                        }
                        Ayame.Tumbler {
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

                Ayame.Frame {
                    Layout.fillWidth: true
                    padding: 0

                    ColumnLayout {
                        width: parent.width
                        spacing: 0

                        Ayame.ItemDelegate {
                            text: "ItemDelegate (Standard)"
                            Layout.fillWidth: true
                            onClicked: Origami.ToastBus.info("Clicked ItemDelegate")
                        }

                        Ayame.CheckDelegate {
                            text: "CheckDelegate (Checked)"
                            checked: true
                            Layout.fillWidth: true
                        }

                        Ayame.RadioDelegate {
                            text: "RadioDelegate (Option)"
                            checked: false
                            Layout.fillWidth: true
                        }

                        Ayame.SwitchDelegate {
                            text: "SwitchDelegate (Toggle)"
                            checked: true
                            Layout.fillWidth: true
                        }

                        Ayame.SwipeDelegate {
                            text: "SwipeDelegate (Swipeable)"
                            Layout.fillWidth: true
                            swipe.right: Rectangle {
                                width: 100
                                height: parent.height
                                color: "#ef4444"
                                Ayame.Label {
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

                Ayame.TabBar {
                    id: ayameTabBar
                    Layout.fillWidth: true

                    Ayame.TabButton {
                        text: "Tab Overview"
                    }
                    Ayame.TabButton {
                        text: "Tab Details"
                    }
                    Ayame.TabButton {
                        text: "Tab Settings"
                    }
                }

                StackLayout {
                    currentIndex: ayameTabBar.currentIndex
                    Layout.fillWidth: true
                    implicitHeight: 60

                    Ayame.Frame {
                        Ayame.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 1: Overview Panel"
                        }
                    }
                    Ayame.Frame {
                        Ayame.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 2: Details & Stats"
                        }
                    }
                    Ayame.Frame {
                        Ayame.Label {
                            anchors.centerIn: parent
                            text: "Content of Tab 3: Settings Panel"
                        }
                    }
                }

                RowLayout {
                    spacing: 16

                    Ayame.Button {
                        text: "Open Ayame Dialog"
                        highlighted: true
                        onClicked: ayameDialog.open()
                    }

                    Ayame.Button {
                        text: "Open Ayame Popup"
                        onClicked: ayamePopup.open()
                    }

                    Ayame.Button {
                        text: "Toggle Side Drawer"
                        onClicked: ayameDrawer.open()
                    }
                }
            }
        }
    }

    // Modal Ayame Dialog
    Ayame.Dialog {
        id: ayameDialog
        title: "Ayame Modal Dialog"
        modal: true
        anchors.centerIn: parent
        standardButtons: Ayame.Dialog.Ok | Ayame.Dialog.Cancel

        ColumnLayout {
            spacing: 12
            Ayame.Label {
                text: "This is a custom Ayame styled modal dialog."
            }
            Ayame.CheckBox {
                text: "Remember selection"
                checked: true
            }
        }
        onAccepted: Origami.ToastBus.success("Ayame Dialog Accepted")
    }

    // Ayame Popup
    Ayame.Popup {
        id: ayamePopup
        anchors.centerIn: parent
        width: 300
        height: 160
        modal: true
        focus: true
        closePolicy: Ayame.Popup.CloseOnEscape | Ayame.Popup.CloseOnPressOutside

        ColumnLayout {
            anchors.fill: parent
            Ayame.Label {
                text: "Ayame Popup Window"
                font.bold: true
            }
            Ayame.Label {
                text: "Press Escape or click outside to dismiss."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Ayame.Button {
                text: "Close"
                Layout.alignment: Qt.AlignRight
                onClicked: ayamePopup.close()
            }
        }
    }

    // Ayame Drawer
    Ayame.Drawer {
        id: ayameDrawer
        width: 250
        height: root.height
        edge: Qt.LeftEdge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Ayame.Label {
                text: "Ayame Side Drawer"
                font.bold: true
                font.pixelSize: 18
            }

            Ayame.Label {
                text: "Slide-out navigation drawer panel."
                wrapMode: Text.WordWrap
            }

            Ayame.Button {
                text: "Close Drawer"
                onClicked: ayameDrawer.close()
            }
        }
    }
}
