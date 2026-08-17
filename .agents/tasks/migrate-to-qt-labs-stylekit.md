# Migrate Origami's custom widgets onto real Qt.labs.StyleKit CustomControl

Full design rationale: see `/home/tefla/.claude/plans/delegated-rolling-crown.md`
(plan-mode output from the session that designed this — read it before
starting). Companion task: `ayame/.agents/tasks/migrate-to-qt-labs-stylekit.md`
(the shared `AyameStyle` definition lives there — **this task depends on
that one's Phase 0 landing first**, since every `controlType` here is
registered inside `AyameStyle`).

## Why

Origami's genuinely custom widgets (not part of QQC2's built-in roster)
currently read our own hand-rolled `StyleKit.Theme`/`StyleKit.Units`
singleton (`ayame/crates/stylekit`), added earlier this session. Qt ships
a real mechanism for exactly this — `Qt.labs.StyleKit`'s `CustomControl`
(register a widget under a `controlType: <int>` inside a `Style`
definition) + `StyleReader` (the widget reads `styleReader.background.color`
etc. at runtime) — see the ayame-side task file for the full research
writeup on how this module works and was confirmed to actually be present
in this project's Qt 6.11.1.

## Steps

- [ ] Wait for `ayame/.agents/tasks/migrate-to-qt-labs-stylekit.md`'s
      Phase 0 (`AyameStyle` definition) to exist with `CustomControl`
      slots reserved for each widget below.
- [ ] Inventory: re-run `grep -rlE "StyleKit\.(Theme|Units)\b" origami/qml`
      to get the current, authoritative file list (this session's own
      border-color-drift fix and earlier migration passes already
      identified at least `ActionButtonGroup.qml`, `ToggleGroup.qml`,
      `ToggleButton.qml`, `ColorSwatch.qml`, `ToastNotification.qml`,
      `IconButton.qml`, `ActionButton.qml` as candidates — re-check, don't
      trust this list blindly since it may drift).
- [ ] For each widget: add a `CustomControl { controlType: N }` entry to
      `AyameStyle` (coordinate the actual `N` values with the ayame-side
      task so they don't collide), then replace the widget's own
      `StyleKit.Theme.paletteFor(...)`/`StyleKit.Units.*` references with
      a `StyleReader { controlType: N; hovered: ...; pressed: ... }`
      bound to that widget's real interaction state, reading
      `styleReader.background.color`/`styleReader.text.color`/etc.
      instead. Mechanical once the pattern is nailed down on the first
      widget — don't need to plan each file individually.
- [ ] Verify: `cargo check -p origami -p origami-gallery` inside the nix
      dev shell, plus the headless runtime check (`QT_QPA_PLATFORM=offscreen
      cargo run -p origami-gallery`, errors via `journalctl --user --since
      <ts> -o cat` — established this session, this environment sends
      Qt's QML load errors there, not stdout/stderr).
- [ ] Once nothing in this repo references `StyleKit.Theme`/`StyleKit.Units`
      anymore, coordinate with the ayame-side task's Phase 4 (retiring
      `crates/stylekit` entirely) and with cettila's own direct
      `StyleKit.Theme`/`StyleKit.Units` references if any remain
      (`grep -rlE "StyleKit\.(Theme|Units)\b"` in the `cettila` repo too).
- [ ] Delete this file once done and confirmed working.
