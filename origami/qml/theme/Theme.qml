pragma Singleton
import QtQuick
import la.cettila.Origami 1.0

// Kirigami.Themeの代替。QtQuick標準のSystemPalette(実行中のQQC2スタイル
// -- 通常org.kde.breeze -- が設定するQPaletteをそのまま反映し、ライト/
// ダーク切り替えにも自動追従する)を唯一の色ソースとする。
QtObject {
    id: theme

    readonly property SystemPalette _palette: SystemPalette {
        colorGroup: SystemPalette.Active
    }

    readonly property int window: 0
    readonly property int view: 1
    readonly property int header: 2
    readonly property int tooltip: 3

    readonly property color positiveTextColor: "#27ae60"
    readonly property color negativeTextColor: "#da4453"
    readonly property color neutralTextColor: "#f67400"

    function paletteFor(set) {
        var pal = theme._palette;
        var backgroundColor = pal.window;
        var textColor = pal.windowText;

        if (set === theme.view) {
            backgroundColor = pal.base;
            textColor = pal.text;
        } else if (set === theme.header) {
            backgroundColor = pal.button;
            textColor = pal.buttonText;
        } else if (set === theme.tooltip) {
            backgroundColor = pal.light;
            textColor = pal.windowText;
        }

        return {
            backgroundColor: backgroundColor,
            textColor: textColor,
            highlightColor: pal.highlight,
            highlightedTextColor: pal.highlightedText,
            hoverColor: Qt.rgba(pal.highlight.r, pal.highlight.g, pal.highlight.b, 0.15),
            positiveTextColor: theme.positiveTextColor,
            negativeTextColor: theme.negativeTextColor,
            neutralTextColor: theme.neutralTextColor
        };
    }
}
