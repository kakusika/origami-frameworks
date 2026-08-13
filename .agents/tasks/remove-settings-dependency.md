# Remove origami's dependency on la.cettila.Settings

Origami's own QML (PaneBackdrop.qml, StatusBar.qml) imports
`la.cettila.Settings` (provided by cettila's `cettila-view-settings`
crate), which itself depends on `origami`. This is a dependency cycle
that blocks splitting origami-frameworks into its own repo. Persistence
for both values already lives in `origami-config` (an origami-frameworks
crate), so only the QML-facing cxx-qt wrapper types need to move/change.

Paired task file in the cettila repo:
`cettila/.agents/tasks/remove-origami-settings-dependency.md`.

## Steps

- [ ] Add a `BackgroundState` qml_element to `origami/src/cxxqt_object.rs`
      (read-only: `image_path()`/`pane_opacity()`, same shape as the one
      currently in `cettila-view-settings`, backed directly by
      `origami_config::settings::load_background_image_path` /
      `load_background_pane_opacity` -- same pattern as the existing
      `LayoutLockSettings`/`ResizeLockSettings` types in that file).
- [ ] Update `origami/qml/pane/PaneBackdrop.qml`: drop
      `import la.cettila.Settings 1.0` now that `BackgroundState` is
      provided by origami's own `la.cettila.Origami` module (already
      imported in this file). Update the class comment accordingly.
- [ ] Update `origami/qml/regions/statusbar/StatusBar.qml`: drop
      `import la.cettila.Settings 1.0` and the inline
      `StatusBarSettings {}` instantiation. Replace the settings-read
      `visible` binding with a plain injected `statusBarVisible` property
      (default `true`) that the composition root binds. Update the class
      comment.
- [ ] `cargo check -p origami` (or the workspace) to confirm origami
      builds without `cettila-view-settings` in scope.

## Notes

- `StatusBarSettings` (read/write, includes `set_status_bar_visible`,
  refresh interval) stays in `cettila-view-settings` -- it's genuinely
  app-specific (used by the settings screen UI and
  `StatusBarSysInfo.qml`), and origami no longer needs to read it itself.
- Wiring `StatusBar.statusBarVisible` from the app side happens in the
  cettila repo (`apps/desktop-qml/qml/main.qml`) -- tracked in the paired
  task file there.
