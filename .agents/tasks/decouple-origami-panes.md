# Decouple `origami` from `origami-panes`

`origami` (the Slint component library) carries a `Cargo.toml` dependency
on `origami-panes` (the headless pane/layout engine) purely as leftover
backward-compat from the `69d9b45` extraction refactor: `origami/src/lib.rs`
re-exports `origami_panes::{drop, edit, layout, outline, pane_tree}` so
old `origami_slint::{pane_tree,layout,drop}` call sites wouldn't need to
change. The actual `.slint` widgets (`PaneHost`, `PaneManager`, ...) never
referenced `origami_panes` types -- they take plain Slint structs
(`PaneCell`, `PaneOutlineRow`). Removing the re-export restores the
intended split: `origami` = components, `origami-panes` = layout engine,
assembled by the app.

Confirmed consumers and their current state:
- `origami-gallery` (this repo): uses the re-export
  (`origami::{edit,layout,outline,pane_tree}` in `src/main.rs`). Needs
  fixing.
- `mumeum` (`../mumeum`): already imports `origami_panes::*` directly
  everywhere and already depends on `origami-panes` explicitly. **No
  change needed.**
- `nidi` (`../nidi`): uses the re-export
  (`origami::{edit,layout,pane_tree}` in `apps/editor/src/main.rs`) and
  has **no** `origami-panes` dependency anywhere in its `Cargo.toml`s.
  Needs fixing (cross-repo).
- `cettila`: out of date (still on pre-rename `origami-slint`/`ayame-*`
  crate names), not a real consumer of current `origami`. Skipped per
  user.

## Steps

- [x] `origami-frameworks`: fix `origami-gallery/src/main.rs` imports to
      `origami_panes::{edit,layout,outline,pane_tree}`.
- [x] `origami-frameworks`: add `origami-panes = { workspace = true }` to
      `origami-gallery/Cargo.toml`.
- [x] `origami-frameworks`: remove the re-export block (and stale doc
      comment) from `origami/src/lib.rs`.
- [x] `origami-frameworks`: remove `origami-panes` dependency from
      `origami/Cargo.toml`.
- [x] `origami-frameworks`: `cargo build --workspace` and
      `cargo test --workspace` pass.
- [x] `origami-frameworks`: commit and push to `origin/main` (split into
      `b72f307` panes-decoupling + `be5e5e4` richtext fix; the latter was
      accidentally bundled with the former by a concurrent session, then
      `git reset` + re-split + `--force-with-lease` push, per user).
- [x] `nidi`: add `origami-panes` to `[workspace.dependencies]` in
      `Cargo.toml` (git dep, same as `origami`).
- [x] `nidi`: add `origami-panes = { workspace = true }` to
      `apps/editor/Cargo.toml`.
- [x] `nidi`: fix `apps/editor/src/main.rs` imports to
      `origami_panes::{edit,layout,pane_tree}`.
- [x] `nidi`: update `Cargo.lock` (pulls the just-pushed `origami-frameworks`
      commit) and confirm it builds. `cargo update -p origami -p
      origami-panes` locked to `be5e5e4`; `cargo build --workspace`
      passed.
- [ ] Check with user before committing/pushing in `nidi` (not yet
      confirmed, unlike the `origami-frameworks` push).

## Next (separate task, not started here)

Plan `origami-mobile` integration into `origami-frameworks` (crate split,
token/theme bridging) together with the user once this is done.
