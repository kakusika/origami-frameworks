# origami

Rustの型を持たない、複数クレートから使うQML部品を集めたクレート。
Pure QMLモジュール(`la.cettila.Origami`)で、Rust側の型は公開しない。

KDE Kirigamiには依存しない(`org.kde.kirigami`は一切importしない)。
アプリ全体で、素のQtQuick/QtQuick.Controlsだけでは足りない部分
(テーマ配色・単位・アイコン表示)はすべてOrigamiが肩代わりする。
`org.kde.kirigami`をimportして良いのはOrigami自身であって、Origamiの外側の
コード(`apps/desktop-qml`、他のview crateのQML)からは一切importしない、
という決め事だったが、Kirigami自体への依存を完全に断ったことで、この決め事
は「Origamiの外はKirigamiを直接使わない」から「アプリ全体がKirigamiを使わ
ない」に変わった。QtQuick Controlsの見た目スタイル(`kdePackages.qqc2-breeze-style`、
`QT_QUICK_CONTROLS_STYLE=org.kde.breeze`)はKirigami QMLモジュールとは別物
なので引き続き使う。

## 提供するもの

### Theme / Units / Icon

Kirigami.Theme/Kirigami.Units/Kirigami.Iconの代替。

- `Theme`(singleton) -- `Theme.paletteFor(set)`(`set`は`Theme.window`/
  `Theme.view`/`Theme.header`/`Theme.tooltip`)で、その時点の配色を
  プレーンなオブジェクト(`{backgroundColor, textColor, highlightColor,
  highlightedTextColor, hoverColor, positiveTextColor, ...}`)として返す。
  色のソースはQtQuick標準の`SystemPalette`(実行中のQQC2スタイルが設定
  したQPaletteをそのまま反映、ライト/ダーク自動追従)。
  Kirigamiの「colorSet」のような部分木への自動継承はない
  -- cxx-qt 0.9.1にQML attached propertyを生成する機構が無いため
  採用できなかった。各コンポーネントはルートで
  `readonly property var colors: Theme.paletteFor(Theme.header)`のように
  一度だけ取得し、子要素は`root.colors.xxx`で参照する。
- `Units`(singleton) -- `gridUnit`/`smallSpacing`/`largeSpacing`/
  `iconSizes`/`cornerRadius`/`shortDuration`等、Kirigami.Unitsと同じ
  命名の定数群。`gridUnit`はQtQuick標準の`FontMetrics`から算出する。
- `Icon`(`qml/controls/Icon.qml`) -- `QtQuick.Controls.impl.IconImage`
  (Qt本体が提供するprivate実装モジュールで、QQC2スタイル自身が
  `icon.name`解決に使っているもの)をラップし、Kirigami.Iconと同じ
  `source`(アイコンテーマ名の文字列)というAPIを保つ。Kirigami.Iconが
  symbolicアイコンをTheme経由で自動着色していたのに対し、Iconには
  そのような暗黙の継承はないため、着色が必要な呼び出し側は明示的に
  `color`を渡す。

各colorSetの対応はQPaletteのロールによる近似であり、Breezeの実際の
カラースキームファイル(KColorScheme由来)とピクセル単位で一致するわけ
ではない。`Kirigami.ShadowedRectangle`のドロップシャドウ効果も、対応する
プレーンなQtQuick機構が無いため簡略化して落としている(プレーンな
`Rectangle`のradius+borderのみ)。

### Rust側ヘルパーモジュール

冒頭の「Rustの型を持たない」はQMLコンポーネント本体の話で、
それとは別に他クレートから`path`依存で使う小さなRustヘルパーも
このクレートがホストしている(QML型としては公開しない、`pub mod`の
プレーン関数/構造体):

- `fs_entries`(`src/fs_entries.rs`) -- `DEFAULT_ROOT`(vault未実装の
  暫定固定パス、`cettila-config::workspace::DEFAULT_VAULT_ROOT`と同じ
  `sandbox/`を指す)、`list_dir`/`list_dir_filtered`/
  `parse_extension_filter`、`move_entries_to`。`cettila-view-explorer`が
  唯一の呼び出し元 -- `ExplorerGridModel`/`ExplorerTreeModel`自体は
  `configure()`で拡張子フィルタとルート境界(`DEFAULT_ROOT`固定でなく
  任意)を設定できるようになっており、Explorer本来のペイン用途に加えて
  `ImagePickerDialog`/`MediaPickerDialog`(`cettila-view-explorer`側へ
  移設済み -- 元は本クレートに`image_picker_model.rs`/
  `media_picker_model.rs`として存在していたが、`origami`は
  `cettila-view-explorer`の依存元であり逆方向のQMLインポートができない
  ため、モデルと同じクレートへ移した。詳細は`crates/views/explorer`の
  `TASKS.md`を参照)としても使われる。
- `fs_watch`(`src/fs_watch.rs`) -- `notify`クレートを使ったディレクトリ
  監視。同じく`cettila-view-explorer`が使う。

### CollapsiblePanel

Blender風の、開いている間は任意の中身を表示し、閉じると矢印ボタン
1つの細い帯に縮む可動サイドパネル(`qml/CollapsiblePanel.qml`)。

### Pane

VS Code/Qt Creatorのような、ドラッグ&ドロップでタブを画面端に
持っていくとその方向へ分割される汎用ペイン(ドッキング)システム。

`apps/desktop-qml`で、それまでの`Kirigami.NavigationTabBar` +
`StackLayout`によるタブ切り替えを置き換える形で導入した。

- `PaneView` — ルートコンポーネント。`initialTabs: [{title, component}, ...]`
  を渡すと、1つのリーフ(タブ集合)から成る初期状態を組み立てる。
- 内部コンポーネント(`PaneNode`/`PaneSplit`/`PaneLeaf`/`PaneTabBar`/
  `PaneTabHeader`/`PaneDropOverlay`)。`PaneView`経由でのみ使う想定で、
  単独では使わない。

複数の`PaneView`インスタンス(例: サイドバー用とメインエリア用)を
同時に使うことができ、controller(=`PaneView`インスタンス)をまたいだ
タブのドラッグ移動にも対応する。

#### 配置モデル

配置は再帰的な二分木で表現する(`PaneView.qml`の`tree`プロパティ)。

- `split`ノード: `orientation`("horizontal"|"vertical")と、
  `{size, node}`の配列(`children`)を持つ。`size`は0〜1の比率。
- `leaf`ノード: タブの配列(`{id, title, component, item}`)と
  `currentIndex`を持つ。

タブの中身は`component`(QML `Component`)を1回だけ`createObject()`して
`item`にキャッシュし、以後はどのペインに移動しても同じ`Item`を
reparentして使い回す(`PaneView.materialize()`)。GraphViewのような
コストの高い/状態を持つビューを、ペイン移動のたびに作り直さないため。

木を変更する関数(`requestDrop`/`extractTab`/`insertTab`/`closeTab`/
`closeAllTabs`/`closeGroup`)は、
JSオブジェクトの内部ミューテーションがQMLのプロパティ変更通知を
発火させないため、必ず「木を複製 → 複製側を変更 → `tree`プロパティへ
代入し直す」という形で実装している。子孫の`PaneNode`/`PaneSplit`/
`PaneLeaf`は、`node`プロパティの再代入を通じて再評価される。

#### ドラッグ&ドロップ実装で踏んだ落とし穴

QtQuickの`Drag`/`DropArea`まわりで、動くように見えて実は動いていない
という状態を何度も踏んだ。同じ轍を踏まないための記録:

1. **PaneNode/PaneSplitの循環参照**: `PaneNode`(node.typeに応じて
   `PaneSplit`か`PaneLeaf`を出し分けるディスパッチャ)と`PaneSplit`
   (子として`PaneNode`を使う)を、互いに型として(`import`経由で)
   静的参照すると、QMLエンジンが"Cyclic dependency detected"を出して
   ロードに失敗する。`PaneNode`側は`Loader.sourceComponent`ではなく
   `Loader.source`(相対URL文字列)による遅延読み込みに変えることで
   断ち切っている。
2. **ドラッグ対象アイテムのサイズ**: ドラッグ中に画面全体を覆う
   `DropArea`との当たり判定は、ドラッグ対象アイテム自身の矩形
   (位置+サイズ)とDropAreaの矩形の重なりで行われる。タブと同じ
   見た目のサイズのアイテムをそのままドラッグ対象にすると、
   ウィンドウの端(まさに分割したい場所)にドロップしようとした瞬間に
   矩形の一部がウィンドウ外へはみ出し、`entered`は来るのに`dropped`が
   発火しない。当たり判定用のアイテムはカーソル位置を表す1x1の点に
   縮小し、見た目の大きさは中の子`Rectangle`(親の矩形の外にもそのまま
   描画される)だけで表現する(`PaneTabHeader.qml`の`dragProxy`)。
3. **`Drag.dragType`の既定値**: Wayland環境では既定の`Drag.Automatic`
   だと、Qtがコンポジタ側の実ドラッグ&ドロップへ昇格させようとし、
   `Drag.mimeData`を設定していないアプリ内完結のドラッグでは
   `entered`/`exited`/`positionChanged`は来るのに`dropped`が一切
   発火しない。`Drag.dragType: Drag.Internal`を明示指定し、QMLシーン
   内だけで完結させる必要がある。
4. **ドロップの確定は`dropped()`に頼らない**: `MouseArea`の
   `onReleased`が発火する時点では、`Drag.active`(→`dragProxy`の
   `Drag.active`)が既にfalseへ遷移済みで、そこから`Drag.drop()`を
   呼んでも不発になる(`dropped()`が飛ばない)ことがある。代わりに、
   ホバー中のたびにドラッグ元(`dragProxy`、`drag.source`)へ「いま
   どのcontroller/leaf/zoneの上にいるか」を書き込んでおき、マウスを
   離した瞬間に`PaneTabHeader.onReleased`がそれを読んで直接
   `controller.requestDrop()`/`extractTab()`+`insertTab()`を呼ぶ
   (`PaneDropOverlay.qml`参照)。
5. **`DropArea.onEntered`/`onPositionChanged`での`drag.accept()`**:
   呼ばないと、そのDropAreaは当該dragを受理しなかった扱いになり、
   以後`entered`/`exited`/`positionChanged`が一切来なくなる。
6. **自ペインへドロップすると`exited()`が発火しない**: ポインタが
   一度もDropAreaの外へ出ないまま(=同じleaf上で)ドラッグを終えると、
   そのDropAreaの`exited()`は発火しない。これに頼ってホバー状態を
   クリアしていると、ハイライトが表示されたまま残る。さらに深刻な
   のは、Qt内部のドラッグ用グラバーもそのDropAreaへ「まだ何かが
   入ったまま」という内部状態を引きずってしまい、**以後そのDropArea
   上で(別のタブであっても)`entered()`が二度と発火しなくなる**こと。
   `MouseArea.onReleased`/`onCanceled`で、`Drag.active`をfalseにする
   *前に*`dragProxy`をドロップ領域の外(例: `x = -100000`)へ実際に
   動かし、正規のジオメトリ変更としての退出を起こして`exited()`を
   強制的に発火させることで後始末する(`PaneTabHeader.qml`参照)。
7. **祖先アイテムによるドラッグの掴みの横取り**: `Kirigami.OverlayDrawer`
   の(`interactiveResizeEnabled`な)端のリサイズハンドルや、
   `SplitView`の分割バーは、いずれも`Flickable`と同様に
   `childMouseEventFilter()`で、進行中のドラッグの掴みを別のMouseAreaが
   持っていても横取りしてくる。奪われると`onReleased`/`onClicked`
   ではなく`onCanceled`が飛んでくる。ドラッグ用の`MouseArea`に
   `preventStealing: true`を設定することで防ぐ(`PaneTabHeader.qml`
   参照)。
8. **自分の葉への辺ゾーンドロップを一律ブロックしない**: 複数タブが
   まとまったleafから1つだけ外へ分割して独立させる、というのは
   正当な操作であり、一律centerとして無視するとタブが一度グループ化
   されたleafはもう二度と分割できなくなってしまう。誤操作(タブを
   持ち上げてすぐ近くで離す)が起きやすいのは、タブバー(=葉の上端)
   から掴んで動かし始める都合上ほぼ確実に一瞬"top"ゾーンを通過する
   ことだが、実際に離す瞬間の判定だけを見れば足りるので、辺ゾーン
   自体を塞ぐ必要はない(`PaneDropOverlay._zoneFor()`参照)。
9. **カスタム描画アイテムのクリッピング**: `GraphRenderItem`
   (Vulkanのカスタム`QSGRenderNode`)は、QMLの`clip: true`が効かない
   (Qt標準の描画パスを経由しない生のVulkanコマンド列を積んでいるため)。
   ペインという「アイテムの矩形に収まる」ことが前提のコンテナへ
   埋め込むには、レンダーノード側でアイテム自身の画面上の矩形へ
   scissorを絞る必要があった(`crates/cettila-view-graph/cpp/graph_render_item.cpp`
   `updatePaintNode()`、および`crates/cettila-renderer/src/graph_render.rs`
   `record()`のscissor_rect引数)。それでもなお、囲む側の`OverlayDrawer`
   /`PaneView`自体が`clip: true`になっていないと、この矩形そのものが
   親の境界(サイドバーの幅など)を越えて描画されてしまう。
