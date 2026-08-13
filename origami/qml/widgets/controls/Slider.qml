import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0

// Blender-style value slider: a single filled bar with no separate
// draggable handle knob, showing the current value as centered text.
//
// A plain Item, not a QQC2.Slider subclass -- this used to subclass
// Slider to get its built-in press-anywhere-to-jump/drag-to-scrub mouse
// handling "for free", but that's exactly the interaction this widget
// replaces (Blender's own sliders don't jump to wherever you first click
// either: a press only starts scrubbing once the pointer has moved past
// `dragThreshold`, and a plain click opens an inline text field instead).
// There's no supported way to turn *off* QQuickSlider's own built-in
// mouse handling from QML -- QQuickItem's acceptedMouseButtons is a
// C++-only API, not a Q_PROPERTY, so assigning it from QML fails to load
// ("Cannot assign to non-existent property"). Rather than fight the base
// class's own input handling, this drops it entirely: `from`/`to`/
// `stepSize`/`value`/`visualPosition` are just plain properties this file
// computes itself, and a single hand-rolled MouseArea owns all pointer
// interaction. `value` is never written by this component itself (same
// "look, don't own the value" split as every other input widget here,
// e.g. ToggleGroup.qml's own class comment) -- only `valueChangeRequested`
// is emitted; the caller decides whether/how to update whatever `value`
// is bound to.
Item {
    id: control

    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property string label: ""
    property int decimals: 2

    // Minimum pointer travel (px) before a press counts as a drag rather
    // than a click. Below this, releasing opens the text-edit field
    // instead of having scrubbed the value.
    property real dragThreshold: Units.smallSpacing

    property bool editing: false

    readonly property real visualPosition: control.to !== control.from ? (control.value - control.from) / (control.to - control.from) : 0

    readonly property var colors: Theme.paletteFor(Theme.view)

    signal valueChangeRequested(real value)

    implicitWidth: Units.gridUnit * 7
    implicitHeight: Units.gridUnit * 1.4

    function _startEditing() {
        control.editing = true;
        editField.text = control.value.toFixed(control.decimals);
        editField.forceActiveFocus();
        editField.selectAll();
    }

    function _commitEdit() {
        var parsed = parseFloat(editField.text);
        if (!isNaN(parsed)) {
            control.valueChangeRequested(Math.min(control.to, Math.max(control.from, parsed)));
        }
        control.editing = false;
    }

    // Blender's own click-drag scrubbing is relative, not absolute: the
    // value moves by how far the pointer has traveled *since the drag
    // started*, anchored to whatever the value already was at that
    // moment -- not snapped to wherever the cursor happens to be over the
    // track. Dragging across the full track width moves the value across
    // its full from/to range regardless of where the press itself landed.
    function _valueForDelta(startValue, deltaX, width) {
        var raw = startValue + (deltaX / width) * (control.to - control.from);
        if (control.stepSize > 0) {
            raw = Math.round(raw / control.stepSize) * control.stepSize;
        }
        return Math.min(control.to, Math.max(control.from, raw));
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Units.cornerRadius
        color: control.colors.backgroundColor
        border.width: Units.borderWidth
        border.color: Qt.rgba(control.colors.textColor.r, control.colors.textColor.g, control.colors.textColor.b, 0.3)

        // A rounded rectangle's actual silhouette pinches inward (lower
        // usable height) the closer x gets to its left/right edge -- true
        // of *any* rounded rect, this fill included, not something a
        // differently-computed corner radius can route around. Giving the
        // fill its own (value-driven, shrinking) width and asking Qt to
        // round *that* rectangle doesn't work: Qt clamps a small
        // rectangle's own corner radius down to fit its shrunken width,
        // while the track's own (always-wide, unclamped) radius doesn't
        // shrink to match, so the two curves stop lining up and fill color
        // shows past where the track's rounding should hide it.
        //
        // Fix: draw the fill Rectangle at the track's *full* inner
        // width/height always (so its corner radius is computed once
        // against a size that never shrinks, and its curve is therefore
        // always identical to the track's own), and reveal only the
        // filled portion by clipping it inside a plain Item sized to the
        // current fill width. Item.clip is always a straight-edged
        // (axis-aligned) cut, never shape-aware -- but that's exactly
        // sufficient here, since the cut only ever needs to slice a
        // vertical line through the right side of an already-correctly-
        // curved shape; the left corner underneath is untouched by that
        // cut, so it keeps matching the track's own curve pixel-for-pixel
        // at any fill amount, including a sliver near the very minimum.
        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: Math.max(0, (track.width - 2) * control.visualPosition)
            clip: true

            Rectangle {
                width: track.width - 2
                height: parent.height
                radius: Units.cornerRadius
                // No hover-driven shade -- only pressed (actually held
                // down, whether that turns into a drag or a click)
                // darkens it.
                color: dragArea.pressed ? Qt.darker(control.colors.highlightColor, 1.2) : control.colors.highlightColor
                opacity: control.enabled ? 1.0 : 0.4
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
            anchors.fill: parent
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
