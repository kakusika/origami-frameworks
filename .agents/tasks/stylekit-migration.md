# Migrate Origami to the StyleKit QML module

Full design rationale: see `/home/tefla/.claude/plans/delegated-rolling-crown.md`
(plan-mode output from the session that designed this). Companion task:
`ayame/.agents/tasks/stylekit-module.md` (must land first — this repo
consumes the `StyleKit` module Ayame's build now provides) and
`cettila/.agents/tasks/stylekit-migration.md` (same migration, cettila's
own direct references).

Unrelated to the pre-existing uncommitted `async-pane-materialize` work
already in this working tree (`.agents/tasks/async-pane-materialize.md`)
— do not touch pane-materialization files while doing this.

## Why

See ayame's task file. Origami's own `qml/theme/Theme.qml`/`Units.qml` are
a drifted duplicate of Ayame's canonical copy; delete them and depend on
the new `StyleKit` module instead.

## Important note on nix

`nix/dev.nix`'s `ayame` input, and `flake.nix`'s `inputs.ayame`, point at
the REMOTE `github:kakusika/ayame` — not the local `../ayame` checkout
where the `StyleKit` module was actually added. So `nix develop`'s
`QML_IMPORT_PATH`/`import StyleKit` runtime resolution here still uses the
old, unmodified remote ayame (without `StyleKit`), until either that repo
is published/re-pinned, or you explicitly test with `nix develop
--override-input ayame path:../ayame` (not yet done). This does NOT block
`cargo check`, which never needed cross-module QML resolution at Rust
build time (verified: `qmlcachegen` degrades gracefully on unresolved
cross-module imports, confirmed against `ayame-settings`'s existing
`import Ayame` precedent).

## Steps

- [x] `origami/build.rs`: removed the two `QmlFile::from("qml/theme/...").singleton(true)`
      lines from the `"la.cettila.Origami"` module's first `.qml_files([...])` list.
- [x] Deleted `origami/qml/theme/Theme.qml` and `origami/qml/theme/Units.qml`
      (`git rm -f`; they already had unrelated uncommitted local edits from
      other work, superseded by this deletion).
- [x] `nix/dev.nix`: uncommented `ayame` in `buildInputs` and in the
      `QML_IMPORT_PATH` list. See "Important note on nix" above though --
      this alone doesn't make it the LOCAL ayame with StyleKit.
- [x] Migrated all 80 files (both this repo's `origami/qml/` and cettila's
      direct references combined) that referenced `Origami.Theme`/`Origami.Units`:
      added `import StyleKit 1.0 as StyleKit` next to the existing `import
      la.cettila.Origami ...` line, rewrote `Origami.Theme` -> `StyleKit.Theme`
      / `Origami.Units` -> `StyleKit.Units` (word-boundary guarded --
      confirmed `Origami.ThemedMenu`/`ThemedSubMenu` were NOT touched).
- [x] `cargo check -p origami` passes (`nix develop --command cargo check
      -p origami`; plain `cargo check` outside the dev shell fails early on
      missing QMAKE/Qt env vars, unrelated to this change).
- [x] `grep -rlE "Origami\.Theme\b|Origami\.Units\b" origami/qml` returns
      nothing.
- [x] Also caught and migrated `origami-gallery/qml/OrigamiWidgetsPage.qml`
      (a separate workspace crate that also references `Origami.Theme`/
      `Origami.Units` directly -- initial grep scope was too narrow,
      limited to `origami/qml/`; re-ran across the whole repo tree and
      found this one straggler). `cargo check -p origami-gallery` passes
      too.
- [x] cettila's companion task done in the same pass (see
      `cettila/.agents/tasks/stylekit-migration.md`).
- [x] Runtime verification, superseding the "Important note on nix" caveat
      above: ayame's own fix (see its task file, "Second bug found after
      the fact") turned out to make `QML_IMPORT_PATH` mostly moot for this
      project's Rust-linked apps anyway -- cxx-qt-build QML modules
      register via Rust static initializers at process startup, not real
      dlopen'd `.so` plugins found via directory scanning. Verified
      headlessly (`QT_QPA_PLATFORM=offscreen` + journald, since Qt's QML
      load errors don't show up in plain stdout/stderr here) that
      `cargo run -p origami-gallery` now starts with zero QML errors, using
      the LOCAL `../ayame` checkout via `.cargo/config.toml`'s Rust-level
      patch (unaffected by the flake's remote `ayame` input pin).
- [ ] Delete this file once the user has reviewed/confirmed the change.
