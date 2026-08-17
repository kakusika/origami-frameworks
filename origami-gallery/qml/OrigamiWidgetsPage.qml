import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

QQC2.ScrollView {
    id: root
    contentWidth: availableWidth
    clip: true

    property real sampleSliderValue: 42
    property real sampleNumberValue: 15
    property color sampleColor: "#3b82f6"
    property string bannerMessage: ""

    ColumnLayout {
        width: parent.width - 40
        spacing: 24
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 20
        anchors.bottomMargin: 40

        // Banner overlay test area if active
        Origami.IoErrorBanner {
            Layout.fillWidth: true
            message: root.bannerMessage
            onDismissed: root.bannerMessage = ""
        }

        // Title Header
        ColumnLayout {
            spacing: 4
            Origami.Label {
                text: "Origami Widgets Catalog"
                font.pixelSize: 22
                font.bold: true
            }
            Origami.Label {
                text: "Custom themed component library for creative-tool pane UI (la.cettila.Origami)"
                type: "secondary"
            }
        }

        // ---------------------------------------------------------
        // Section 1: Buttons & Action Controls
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "1. Buttons & Action Controls"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                Origami.Label {
                    text: "ActionButton Variants:"
                    font.bold: true
                }

                RowLayout {
                    spacing: 12

                    Origami.ActionButton {
                        text: "Standard Action"
                        tooltip: "Standard ActionButton"
                    }
                    Origami.ActionButton {
                        text: "Highlighted"
                        tooltip: "Primary action"
                    }
                    Origami.ActionButton {
                        text: "Destructive"
                        destructive: true
                        tooltip: "Dangerous action"
                    }
                    Origami.ActionButton {
                        text: "Disabled"
                        enabled: false
                    }
                }

                Origami.Separator {
                    Layout.fillWidth: true
                    implicitHeight: 1
                }

                Origami.Label {
                    text: "Segmented Button Groups & Menus:"
                    font.bold: true
                }

                RowLayout {
                    spacing: 16

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "ActionButtonGroup:"
                            type: "secondary"
                        }
                        Origami.ActionButtonGroup {
                            actions: [
                                {
                                    iconName: "document-new",
                                    onTriggered: function () {
                                        Origami.ToastBus.info("New document created");
                                    }
                                },
                                {
                                    iconName: "document-save",
                                    onTriggered: function () {
                                        Origami.ToastBus.success("Saved successfully");
                                    }
                                },
                                {
                                    iconName: "edit-delete",
                                    destructive: true,
                                    onTriggered: function () {
                                        Origami.ToastBus.error("Deleted item");
                                    }
                                }
                            ]
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "DropdownButton:"
                            type: "secondary"
                        }
                        Origami.DropdownButton {
                            text: "Options"
                            iconName: "preferences-system-symbolic"
                            menuItems: [
                                {
                                    text: "Option A",
                                    onTriggered: function () {
                                        Origami.ToastBus.info("Selected Option A");
                                    }
                                },
                                {
                                    text: "Option B",
                                    onTriggered: function () {
                                        Origami.ToastBus.info("Selected Option B");
                                    }
                                },
                                {
                                    text: "Disabled Item",
                                    enabled: false
                                }
                            ]
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "HamburgerButton:"
                            type: "secondary"
                        }
                        Origami.HamburgerButton {
                            text: "Menu"
                            iconName: "open-menu-symbolic"
                            menuItems: [
                                {
                                    text: "View Details"
                                },
                                {
                                    text: "Refresh"
                                },
                                {
                                    text: "Settings"
                                }
                            ]
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "IconButton:"
                            type: "secondary"
                        }
                        Origami.IconButton {
                            iconName: "edit-find-symbolic"
                            onClicked: Origami.ToastBus.info("Search clicked")
                        }
                    }
                }

                Origami.Separator {
                    Layout.fillWidth: true
                    implicitHeight: 1
                }

                Origami.Label {
                    text: "Toggles & Segmented Selection:"
                    font.bold: true
                }

                RowLayout {
                    spacing: 20

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "ToggleButton:"
                            type: "secondary"
                        }
                        Origami.ToggleButton {
                            id: sampleToggle
                            iconName: "view-refresh-symbolic"
                            checked: false
                            onToggled: function (c) {
                                checked = c;
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 4
                        Origami.Label {
                            text: "ToggleGroup (Segmented):"
                            type: "secondary"
                        }
                        Origami.ToggleGroup {
                            id: sampleToggleGroup
                            value: "grid"
                            options: [
                                {
                                    value: "grid",
                                    iconName: "view-grid-symbolic"
                                },
                                {
                                    value: "list",
                                    iconName: "view-list-symbolic"
                                },
                                {
                                    value: "tree",
                                    iconName: "view-sort-ascending-symbolic"
                                }
                            ]
                            onValueChangeRequested: function (v) {
                                value = v;
                            }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 2: Controls & Indicators
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "2. Controls & Indicators"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                RowLayout {
                    spacing: 24

                    ColumnLayout {
                        spacing: 8
                        Origami.Label {
                            text: "ColorSwatch:"
                            font.bold: true
                        }
                        Origami.ColorSwatch {
                            label: "Pick Color"
                            selectedColor: root.sampleColor
                            onColorPicked: function (col) {
                                root.sampleColor = col;
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 8
                        Origami.Label {
                            text: "Icon & IconStack:"
                            font.bold: true
                        }
                        RowLayout {
                            spacing: 12
                            Origami.Icon {
                                source: "dialog-information-symbolic"
                                width: StyleKit.Units.iconSizes.medium
                                height: StyleKit.Units.iconSizes.medium
                            }
                            Origami.IconStack {
                                iconNames: ["document-open-symbolic", "edit-find-symbolic", "preferences-system-symbolic"]
                            }
                        }
                    }
                }

                Origami.Separator {
                    Layout.fillWidth: true
                    implicitHeight: 1
                }

                Origami.Label {
                    text: "Semantic Label Variants:"
                    font.bold: true
                }

                RowLayout {
                    spacing: 16

                    Origami.Label {
                        text: "Plain Label"
                        type: "plain"
                    }
                    Origami.Label {
                        text: "Secondary Label"
                        type: "secondary"
                    }
                    Origami.Label {
                        text: "Disabled Label"
                        type: "disabled"
                    }
                    Origami.Label {
                        text: "Positive Label"
                        type: "positive"
                    }
                    Origami.Label {
                        text: "Negative Label"
                        type: "negative"
                    }
                    Origami.Label {
                        text: "Neutral Label"
                        type: "neutral"
                    }
                }

                Origami.Separator {
                    Layout.fillWidth: true
                    implicitHeight: 1
                }

                Origami.Label {
                    text: "Blender-style Value Slider:"
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Origami.Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: root.sampleSliderValue
                        label: "Value Slider"
                        onValueChangeRequested: function (v) {
                            root.sampleSliderValue = v;
                        }
                    }
                    Origami.Label {
                        text: "Click & drag to scrub value, or click to type exact number."
                        type: "secondary"
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 3: Input Controls
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "3. Input Controls"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                Origami.Label {
                    text: "Blender-style NumberInput:"
                    font.bold: true
                }

                RowLayout {
                    spacing: 16
                    Layout.fillWidth: true

                    Origami.NumberInput {
                        Layout.preferredWidth: 240
                        from: 0
                        to: 100
                        stepSize: 1
                        value: root.sampleNumberValue
                        label: "Number"
                        onValueChangeRequested: function (v) {
                            root.sampleNumberValue = v;
                        }
                    }

                    Origami.Label {
                        text: "Features: +/- arrow step buttons, drag middle region to scrub, or click to type."
                        type: "secondary"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ---------------------------------------------------------
        // Section 4: Popups, Dialogs & Toast Notifications
        // ---------------------------------------------------------
        Origami.CollapsibleSection {
            title: "4. Popups, Dialogs & Notifications"
            Layout.fillWidth: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                RowLayout {
                    spacing: 12

                    Origami.ActionButton {
                        text: "Trigger Toast (Info)"
                        onClicked: Origami.ToastBus.info("This is an info toast notification")
                    }

                    Origami.ActionButton {
                        text: "Trigger Toast (Success)"
                        onClicked: Origami.ToastBus.success("Operation completed successfully!")
                    }

                    Origami.ActionButton {
                        text: "Trigger Toast (Warning)"
                        onClicked: Origami.ToastBus.warning("Warning: Check system settings")
                    }

                    Origami.ActionButton {
                        text: "Trigger Toast (Error)"
                        onClicked: Origami.ToastBus.error("Error occurred while processing request")
                    }
                }

                RowLayout {
                    spacing: 12

                    Origami.ActionButton {
                        text: "Open Confirm Dialog"
                        highlighted: true
                        onClicked: confirmDialogSample.open()
                    }

                    Origami.ActionButton {
                        text: "Open Color Picker Popup"
                        onClicked: colorPickerSample.open()
                    }

                    Origami.ActionButton {
                        text: "Toggle IoErrorBanner"
                        destructive: true
                        onClicked: {
                            if (root.bannerMessage.length === 0) {
                                root.bannerMessage = "Failed to save file: /path/to/vault/.cettila/workspace.yaml (Permission denied)";
                            } else {
                                root.bannerMessage = "";
                            }
                        }
                    }
                }
            }
        }
    }

    // Sample Confirm Dialog
    Origami.ConfirmDialog {
        id: confirmDialogSample
        title: "Confirm Action"
        message: "Are you sure you want to apply these Origami component changes?"
        onConfirmed: Origami.ToastBus.success("Confirmed action!")
        onCancelled: Origami.ToastBus.info("Cancelled action")
    }

    // Sample Standalone Color Picker Popup
    Origami.ColorPickerPopup {
        id: colorPickerSample
        selectedColor: root.sampleColor
        onColorAccepted: function (col) {
            root.sampleColor = col;
            Origami.ToastBus.success("Color updated to " + col.toString());
        }
    }
}
