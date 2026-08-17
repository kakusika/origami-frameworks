import QtQuick
import QtQuick.Controls as QQC2
import la.cettila.Origami 1.0 as Origami
import StyleKit 1.0 as StyleKit

// Blenderのプロパティエディタのパネルを模した、折りたたみ可能なセクション。
// 角丸+枠線で1つのカプセルとして視覚的に独立させ、ヘッダー行(矢印+
// タイトル)をクリックすると中身(body)だけを開閉する。設定画面に限らず、
// 複数のグループを持つページ全般で、タブを増やさずセクションを積み重ねる
// だけで済むようにするための汎用部品(設定画面のほかBookmarksSidebar.qml/
// Properties.qmlでも使われている)。
//
// 使い方:
//
//   CollapsibleSection {
//       width: parent.width
//       title: "..."
//
//       Label { text: "..." }
//   }
//
// デフォルトプロパティとして渡した子はボディのColumn内に縦積みされる。
Rectangle {
    id: root

    property string title: ""
    property bool expanded: true

    // Optional header-left enable/disable switch (between arrow icon and title, e.g. SettingsPage.qml's
    // "アニメーション"/"ステータスバー" sections) -- caller decides whether/
    // how to update whatever `toggleChecked` is bound to, same "look, don't
    // own the value" split ToggleGroup.qml's own `value`/
    // `valueChangeRequested` uses. When shown and unchecked, this
    // component disables (and dims) its own body -- the whole section
    // reads as "off" without the caller needing to gate each individual
    // child control itself.
    property bool showToggle: false
    property bool toggleChecked: true
    signal toggleRequested(bool checked)

    // Optional header-right "template" dropdown, shown just right of the
    // toggle above (e.g. a "デフォルト"/"カスタム" picker that resets the
    // section's own settings to their app defaults) -- same data-driven
    // menuItems idiom DropdownButton.qml itself uses, just forwarded
    // through so this component doesn't need its own popup plumbing.
    property bool showTemplate: false
    property string templateText: ""
    property var templateMenuItems: []

    // ページ本体(SettingsPage.qmlはTheme.viewを使う)と区別が付くよう、
    // 別のcolorSetを使う。
    readonly property var colors: StyleKit.Theme.paletteFor(StyleKit.Theme.window)

    // Shared by body and the title label below, so both dim together when
    // the toggle is off -- the toggle itself and the expand/collapse arrow
    // stay at full opacity since they remain interactive either way.
    readonly property bool toggleEnabled: !root.showToggle || root.toggleChecked

    default property alias content: body.data

    implicitWidth: StyleKit.Units.gridUnit * 16
    implicitHeight: header.height + (root.expanded ? body.implicitHeight + StyleKit.Units.smallSpacing : 0)
    height: root.implicitHeight

    radius: StyleKit.Units.cornerRadius
    color: root.colors.backgroundColor
    border.width: StyleKit.Units.borderWidth
    border.color: Qt.rgba(root.colors.textColor.r, root.colors.textColor.g, root.colors.textColor.b, 0.2)
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: StyleKit.Units.shortDuration
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: StyleKit.Units.gridUnit * 1.6
        radius: StyleKit.Units.cornerRadius
        color: headerHover.hovered ? root.colors.hoverColor : "transparent"

        // MouseArea handles expand/collapse on clicking the header background,
        // title, or arrow icon. Interactive child controls (Switch, DropdownButton)
        // defined after MouseArea consume their own mouse events, preventing section
        // toggle when clicking those controls.
        HoverHandler {
            id: headerHover
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }

        Row {
            id: leadingRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: StyleKit.Units.smallSpacing
            spacing: StyleKit.Units.smallSpacing

            Origami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                source: root.expanded ? "chevron-down" : "chevron-right"
                width: StyleKit.Units.iconSizes.small
                height: StyleKit.Units.iconSizes.small
                color: root.colors.textColor
            }

            QQC2.Switch {
                anchors.verticalCenter: parent.verticalCenter
                height: header.height - 4
                visible: root.showToggle
                checked: root.toggleChecked
                onToggled: root.toggleRequested(checked)
            }

            Origami.Label {
                anchors.verticalCenter: parent.verticalCenter
                colorSet: StyleKit.Theme.window
                text: root.title
                font.bold: true
                opacity: root.toggleEnabled ? 1.0 : 0.5

                Behavior on opacity {
                    NumberAnimation {
                        duration: StyleKit.Units.shortDuration
                    }
                }
            }
        }

        Row {
            id: trailingRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: StyleKit.Units.smallSpacing
            spacing: StyleKit.Units.smallSpacing
            visible: root.showTemplate

            Origami.DropdownButton {
                height: header.height - 4
                visible: root.showTemplate
                text: root.templateText
                menuItems: root.templateMenuItems
            }
        }
    }

    Column {
        id: body
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: StyleKit.Units.smallSpacing
        anchors.topMargin: 0
        spacing: StyleKit.Units.smallSpacing
        visible: root.expanded

        // The toggle above governs whether this section's own settings
        // apply at all -- disabling (and dimming) the body when it's off
        // means every child control here reads as inert without each one
        // needing its own `enabled: Units.somethingEnabled` binding.
        enabled: root.toggleEnabled
        opacity: root.toggleEnabled ? 1.0 : 0.5

        Behavior on opacity {
            NumberAnimation {
                duration: StyleKit.Units.shortDuration
            }
        }
    }
}
