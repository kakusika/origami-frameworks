pragma Singleton
import QtQuick
import la.cettila.Origami 1.0
import Ayame 1.0 as Ayame

// Kirigami.Unitsの代替。フォントサイズから導いた基本単位(gridUnit)を
// 起点に、間隔・アイコンサイズ・角丸半径・アニメーション時間の定数を
// 提供する。すべてKirigami非依存(QtQuick標準のFontMetricsのみ使用)。
QtObject {
    id: units

    readonly property FontMetrics _metrics: FontMetrics {
        font: Qt.application.font
    }

    readonly property Ayame.UiScaleSettings _uiScaleSettings: Ayame.UiScaleSettings {}

    // Read the persisted value once at startup. Changes only afterward
    // through setUiScale() -- same seed-once-then-update-live shape as
    // cornerRadiusOption/borderWidthOption below.
    property real uiScale: units._uiScaleSettings.scale()

    // Called from the settings screen: persists the pick and applies it
    // app-wide immediately -- gridUnit and iconSizes below both derive
    // from this, so every size bound to Units.gridUnit or
    // Units.iconSizes.* rescales the instant this changes, no restart
    // needed.
    function setUiScale(scale) {
        units._uiScaleSettings.set_scale(scale);
        units.uiScale = scale;
    }

    readonly property int gridUnit: Math.round(units._metrics.height * units.uiScale)
    readonly property int smallSpacing: Math.max(2, Math.floor(units.gridUnit / 4))
    readonly property int largeSpacing: units.smallSpacing * 2

    // Margin between a "framed" pane group's outer border and its own
    // content container -- currently PaneLeaf.qml's groupArea (the
    // "tabs" node case) and PaneDrawer.qml's bodyArea (the "drawer" node
    // case); "split"/standalone "pane" are never framed, see
    // PaneNode.qml's class comment. Its own constant (not just reusing
    // Units.smallSpacing directly) since this specific gap wanted to be
    // narrower than every other Units.smallSpacing use in the app.
    readonly property int groupContentMargin: Math.max(1, Math.floor(units.smallSpacing / 2))

    // Maps the settings screen's 5-step Appearance/corner-radius preset
    // onto a concrete pixel value. "circle" deliberately exceeds any
    // realistic size: QtQuick's Rectangle clamps radius down to half of
    // width/height once it's too large, so an oversized constant is the
    // standard trick for "always fully rounded" (pill/circle) without
    // needing to know the target size.
    readonly property var _cornerRadiusPresets: ({
            circle: 9999,
            large: 14,
            medium: 8,
            small: 4,
            disabled: 0
        })

    readonly property Ayame.CornerRadiusSettings _cornerRadiusSettings: Ayame.CornerRadiusSettings {}

    // Read the persisted value once at startup. Changes only afterward
    // through setCornerRadiusOption() -- binding to a qinvokable's return
    // value doesn't auto-update on its own, since there's no signal
    // telling the binding the underlying value changed.
    property string cornerRadiusOption: units._cornerRadiusSettings.option()

    // Units is a singleton, so this binding re-evaluates every
    // `radius: Units.cornerRadius` across the app the instant
    // cornerRadiusOption changes -- no restart needed.
    readonly property int cornerRadius: units._cornerRadiusPresets[units.cornerRadiusOption] ?? 4

    // Called from the settings screen: persists the pick and applies it
    // app-wide immediately.
    function setCornerRadiusOption(option) {
        units._cornerRadiusSettings.set_option(option);
        units.cornerRadiusOption = option;
    }

    // Maps the settings screen's 3-step Appearance/border-width preset
    // onto a concrete pixel value. "default" matches the fixed 1px width
    // hardcoded everywhere before this setting existed.
    readonly property var _borderWidthPresets: ({
            thin: 0.5,
            default: 1,
            thick: 2
        })

    readonly property Ayame.BorderWidthSettings _borderWidthSettings: Ayame.BorderWidthSettings {}

    // Same seed-once-at-startup shape as cornerRadiusOption above.
    property string borderWidthOption: units._borderWidthSettings.option()

    // Units is a singleton, so this binding re-evaluates every
    // `border.width: Units.borderWidth` across the app the instant
    // borderWidthOption changes -- no restart needed.
    readonly property real borderWidth: units._borderWidthPresets[units.borderWidthOption] ?? 1

    // Called from the settings screen: persists the pick and applies it
    // app-wide immediately.
    function setBorderWidthOption(option) {
        units._borderWidthSettings.set_option(option);
        units.borderWidthOption = option;
    }

    // A drawer's own rail width (PaneDrawer.qml's railWidth, which reads
    // this same constant): a fixed-width vertical column of icon-only
    // tab buttons, always present at this same width whether expanded
    // or collapsed (see PaneDrawer.qml's class comment) -- only the
    // body content beside it toggles. Also PaneSplit.qml's fixed
    // cross-axis size for a collapsed drawer cell nested in a
    // *horizontal* split (its width shrinks down to exactly this, since
    // collapsing removes the body but the rail itself never changes
    // width). Sized to comfortably fit one icon-square button.
    readonly property int collapsedDrawerSize: units.gridUnit * 1.8

    // Maps the settings screen's 3-step Appearance/animation-speed preset
    // onto a duration multiplier applied to every constant below.
    readonly property var _animationSpeedPresets: ({
            slow: 1.5,
            normal: 1.0,
            fast: 0.5
        })

    readonly property Ayame.AnimationSettings _animationSettings: Ayame.AnimationSettings {}

    // Same seed-once-at-startup-then-update-live shape as
    // cornerRadiusOption/borderWidthOption above.
    property string animationSpeedOption: units._animationSettings.speed_option()
    property bool animationsEnabled: units._animationSettings.enabled()

    readonly property real _animationSpeedMultiplier: units._animationSpeedPresets[units.animationSpeedOption] ?? 1.0

    // Called from the settings screen: persists the pick and applies it
    // app-wide immediately (every duration constant below re-evaluates the
    // instant either property changes, no restart needed).
    function setAnimationSpeedOption(option) {
        units._animationSettings.set_speed_option(option);
        units.animationSpeedOption = option;
    }

    function setAnimationsEnabled(enabled) {
        units._animationSettings.set_enabled(enabled);
        units.animationsEnabled = enabled;
    }

    // 0 when animations are turned off app-wide -- a Behavior/NumberAnimation
    // bound to any of these then applies its target value immediately
    // instead of animating, no per-call-site branching needed. Otherwise
    // scaled by the speed preset above.
    readonly property int veryShortDuration: units.animationsEnabled ? Math.round(50 * units._animationSpeedMultiplier) : 0
    readonly property int shortDuration: units.animationsEnabled ? Math.round(150 * units._animationSpeedMultiplier) : 0
    readonly property int longDuration: units.animationsEnabled ? Math.round(300 * units._animationSpeedMultiplier) : 0
    readonly property int veryLongDuration: units.animationsEnabled ? Math.round(500 * units._animationSpeedMultiplier) : 0

    // freedesktopの標準アイコンサイズ。Kirigami.Units.iconSizesと同じ
    // 命名・値を踏襲する(uiScale適用後の値)。
    readonly property QtObject iconSizes: QtObject {
        readonly property int small: Math.round(16 * units.uiScale)
        readonly property int smallMedium: Math.round(22 * units.uiScale)
        readonly property int medium: Math.round(32 * units.uiScale)
        readonly property int large: Math.round(48 * units.uiScale)
        readonly property int huge: Math.round(64 * units.uiScale)
        readonly property int enormous: Math.round(128 * units.uiScale)
    }
}
