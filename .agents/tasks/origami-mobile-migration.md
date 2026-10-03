# `origami-mobile`をorigami-frameworksに統合する

計画の全文は `/home/tefla/.claude/plans/polymorphic-dancing-eclipse.md` を参照
(このファイルはそのサマリー兼進捗トラッカー)。

ソース: `/home/tefla/projects/develop/project-tomet/immermemo/crates/origami-mobile`

## Steps

- [x] `crates/origami-mobile/Cargo.toml` 新規作成(`name = "origami-mobile"`,
      `links = "origami_mobile"`, 依存なし)
- [x] `crates/origami-mobile/build.rs` 新規作成(元の内容をそのままコピー)
- [x] `crates/origami-mobile/ui/icons.slint` 新規作成(無変更コピー)
- [x] `crates/origami-mobile/ui/components.slint` 新規作成(無変更コピー)
- [x] `crates/origami-mobile/ui/tokens.slint` 新規作成(`Colors`→`SystemColors`
      改名 + `ThemeColors`/`Theme`新設 + `Colors`をファサード化)
- [x] `crates/origami-mobile/src/lib.rs` 新規作成(`push_mobile_color_tokens!`
      マクロ)
- [x] ルート`Cargo.toml`: `[workspace.members]`と`[workspace.dependencies]`に
      `origami-mobile`追加
- [x] README.mdに`crates/origami-mobile`の1行追加(ついでに前からあった
      見出し重複`## Crates`/`### Crates`も直した)
- [x] `crates/origami-theme/src/tokens.rs`に`ThemeColors`同期テスト追加
      (`mobile_theme_colors_defaults_match_the_resolved_default_theme`、
      pass確認済み)
- [x] `cargo build --workspace` / `cargo test --workspace` 確認、両方pass
- [x] `slint-viewer crates/origami-mobile/ui/components.slint`で目視確認
      (5秒間エラーなく起動し続けた=インポートグラフ全体が型チェック通過)
- [ ] コミット(push許可は別途確認)

## 今回やらないこと

計画ファイルの「今回やらないこと」セクション参照
(origami-build連携、immermemo側の追従、gallery表示、アイコン方式の逆輸入)。
