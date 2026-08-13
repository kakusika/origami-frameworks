import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Blender-style number field: drag-to-scrub / click-to-edit + step arrows.
Item {
    id: control

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string label: ""
    property int decimals: 0

    property real dragThreshold: Units.smallSpacing
    property bool editing: false

    readonly property real arrowWidth: Units.gridUnit * 1.2
    readonly property var colors: Theme.paletteFor(Theme.view)

    signal valueChangeRequested(real value)

    implicitWidth: Units.gridUnit * 6
    implicitHeight: Units.gridUnit * 1.4

    function _clamp(v) {
        return Math.min(control.to, Math.max(control.from, v));
    }

    function _step(delta) {
        control.valueChangeRequested(control._clamp(control.value + delta));
    }

    function _startEditing() {
        control.editing = true;
        editField.text = control.value.toFixed(control.decimals);
        editField.forceActiveFocus();
        editField.selectAll();
    }

    function _commitEdit() {
        var parsed = parseFloat(editField.text);
        if (!isNaN(parsed)) {
            control.valueChangeRequested(control._clamp(parsed));
        }
        control.editing = false;
    }

    function _valueForDelta(startValue, deltaX, width) {
        var raw = startValue + (deltaX / width) * (control.to - control.from);
        if (control.stepSize > 0) {
            raw = Math.round(raw / control.stepSize) * control.stepSize;
        }
        return control._clamp(raw);
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Units.cornerRadius
        color: control.colors.backgroundColor
        border.width: Units.borderWidth
        border.color: Qt.rgba(control.colors.textColor.r, control.colors.textColor.g, control.colors.textColor.b, 0.3)
        clip: true

        Rectangle {
            id: leftButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: control.arrowWidth
            topLeftRadius: Units.cornerRadius
            bottomLeftRadius: Units.cornerRadius
            color: leftHover.hovered ? control.colors.hoverColor : "transparent"

            HoverHandler {
                id: leftHover
                enabled: control.enabled && !control.editing
            }

            TapHandler {
                enabled: control.enabled && !control.editing
                onTapped: control._step(-control.stepSize)
            }

            Icon {
                anchors.centerIn: parent
                source: "arrow-left-symbolic"
                color: control.colors.textColor
                width: Units.iconSizes.small
                height: Units.iconSizes.small
                opacity: control.value <= control.from ? 0.4 : 1.0
            }
        }

        Rectangle {
            id: rightButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: control.arrowWidth
            topRightRadius: Units.cornerRadius
            bottomRightRadius: Units.cornerRadius
            color: rightHover.hovered ? control.colors.hoverColor : "transparent"

            HoverHandler {
                id: rightHover
                enabled: control.enabled && !control.editing
            }

            TapHandler {
                enabled: control.enabled && !control.editing
                onTapped: control._step(control.stepSize)
            }

            Icon {
                anchors.centerIn: parent
                source: "arrow-right-symbolic"
                color: control.colors.textColor
                width: Units.iconSizes.small
                height: Units.iconSizes.small
                opacity: control.value >= control.to ? 0.4 : 1.0
            }
        }

        Label {
            anchors.centerIn: parent
            visible: !control.editing
            text: (control.label.length > 0 ? control.label + ": " : "") + control.value.toFixed(control.decimals)
        }

        QQC2.TextField {
            id: editField
            anchors.centerIn: parent
            visible: control.editing
            horizontalAlignment: TextInput.AlignHCenter
            validator: DoubleValidator {
                bottom: control.from
                top: control.to
                decimals: control.decimals
            }
            onEditingFinished: control._commitEdit()
        }

        MouseArea {
            id: dragArea
            anchors.left: leftButton.right
            anchors.right: rightButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            enabled: control.enabled && !control.editing
            preventStealing: true

            property real _pressX: 0
            property real _startValue: 0
            property bool _dragging: false

            onPressed: mouse => {
                dragArea._pressX = mouse.x;
                dragArea._startValue = control.value;
                dragArea._dragging = false;
            }

            onPositionChanged: mouse => {
                if (!dragArea._dragging && Math.abs(mouse.x - dragArea._pressX) >= control.dragThreshold) {
                    dragArea._dragging = true;
                }
                if (dragArea._dragging) {
                    control.valueChangeRequested(control._valueForDelta(dragArea._startValue, mouse.x - dragArea._pressX, width));
                }
            }

            onReleased: {
                if (!dragArea._dragging) {
                    control._startEditing();
                }
                dragArea._dragging = false;
            }
        }
    }
}
