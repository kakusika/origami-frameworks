# ウィジェット・パリティ調査(pane 以外、2026-09-27、コードのみで検証)

`pane-host-parity.md` がペインツリー/ペインホストを網羅しているので、それ以外の QML ウィジェット群を
QML 版(`origami/qml/`、`qml/pane/` 以外)と Slint 版(`origami-kit/{theme,views}`, `origami-slint/`)で
突き合わせた。README・docs 類は見ず、実装コードのみ比較。並列調査1系統の結果。

## 見つかった差: `Separator.qml` に Slint 側の対応コンポーネントが無い

`origami/qml/widgets/controls/Separator.qml` は共有の半透明区切り線(`Qt.rgba(textColor, 0.2)`)で、
区切り線が要る場所全部から使い回されている。Slint 側には `Separator` 相当のコンポーネントが無く、
`menu_bar.slint`・`side_title_bar.slint`・`pane_host.slint`・`tool_bar.slint`・`themed_menu.slint`
それぞれが個別に区切り線の `Rectangle` を手書きしている。

今のところ見た目の食い違いは無い(未検証だが大きくズレていそうな箇所は見当たらなかった)ので実害は
無いが、以下の理由で直しておく価値がある:
- 区切り線のスタイルを変えたいとき、1箇所ではなく5箇所を手で直す必要がある。
- QML 版はアルファ付きの色(`Qt.rgba(..., 0.2)`)で作っている。mumeum 側は不透明トークンのみで半透明
  色を禁じる方針(mumeum の memory `no-translucent-colors`)なので、この QML の実装をそのまま Slint に
  持ってくると方針違反になる。作るなら不透明なトークン色にすること。

直すなら: `separator.slint` を新設して5箇所を差し替える。優先度は低い(壊れていない、見た目の実害も
今のところ無い)。

**対応済み(2026-09-28)**: `origami-slint/ui/separator.slint` を新設(`Separator` 水平・`VerticalSeparator`
垂直、それぞれ `Tokens.divider`/`Tokens.border` を使う不透明色)。`menu_bar.slint`・`pane_host.slint`・
`themed_menu.slint`・`side_title_bar.slint` の4箇所を差し替え済み(`tool_bar.slint` の `ToolBarSeparator` は
固定18px・垂直という別の寸法規約を持つ既存の名前付きコンポーネントなので、今回は据え置き)。
`origami-gallery-slint` のビルドで確認済み。

## 未着手(予算切れ、今回は検証できず)

- アイコンセットの網羅性: `Icon.qml`/`IconStack.qml`(バッジ/オーバーレイの重ね表示など)と
  `icons.slint` の `Icons` enum の対応漏れ。
- テーマパレットのプリセット数: `origami-kit/theme/src/palette/presets.rs` と QML 側の対応(ただし
  QML 側の `StyleKit` は Cettila 自身のアプリコードにあり origami 本体ではないので、比較には注意が必要)。
- `ModalDialog`/`ConfirmDialog` のフォーカストラップ・Escape キー処理。
- アクセシビリティ(QQC2/origami QML の `Accessible.role` 相当が Slint の `accessible-role` にどこまで
  移植されているか)。

## 確認して問題無しと分かったもの(再調査不要)

- `FloatingWindow`/`FloatingWindowHeader`/`FloatingWindowHost`(ドラッグ・8方向リサイズ・最小化/最大化/
  閉じる)→ `floating_window.slint` に機能完全に移植済み。`FloatingWindowRegistry`(z順、アクティブ
  ウィンドウ追跡、シリアライズ/復元)→ `origami-kit/panes/src/floating.rs` の `FloatingWindows`、テスト
  付きで存在。(余談: mumeum 自体はどちらも使っておらず、ペインの切り離しには実 OS ウィンドウを新規に
  開く方式を取っている。フレームワークの欠落ではなく、mumeum 側の設計選択。)
- `ErrorBus.qml` + `ToastBus.qml`(どこからでも投げられるグローバル通知バス)→ `notifications.slint` の
  `Notifications` global に統合済み。同一メッセージの再トリガー用シリアルカウンタの仕掛けも含めて忠実。
- `HeaderMenuCoordinator.qml` のホバー切替(あるメニューのポップオーバーが開いている間に隣のボタンへ
  ホバーすると、クリックせずに切り替わる挙動)→ `menu_bar.slint:229-231` で正しく移植済み。
- `CollapsiblePanel.qml` + `BottomPanel.qml` → `collapsible_panel.slint` に両方の docking モードとも
  構造が一致。
- `DropdownButton.qml` → `components.slint` に存在。
- `origami-kit/vulkan-bridge` に Slint 側の対応物が無いのは欠落ではない: wgpu を Qt Quick の描画
  パイプラインに埋め込むための Qt 専用 interop 層で、Slint のネイティブ wgpu backend
  (`unstable-wgpu-30`、mumeum の link-graph で使用中)には元々不要な層。
- Ayame ウィジェットギャラリーページ(`AyameWidgetsPage.qml`)は origami 自体のウィジェット集ではなく
  サードパーティ QML テーマの参考展示なので、移植対象ではない。
