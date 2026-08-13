# Stop Origami's components from overriding the active QQC2 style

## Correction (2026-08-14, superseding this file's original draft)

The first draft of this file assumed the fix was "move Origami's theme +
widget catalog into Ayame." That was wrong and has been thrown out. The
real problem, and the actual scope:

- Origami is a family of ~53 QML files, almost all built on top of a raw
  `QtQuick.Controls` (QQC2) base type (`QQC2.Button`, `QQC2.Label`,
  `QQC2.AbstractButton`, etc.).
- Many of them explicitly set their own `background:` and/or
  hover/pressed-driven `color:` bindings, which unconditionally overrides
  whatever the *active* QQC2 style would otherwise draw for that control.
- `Theme.qml`/`Units.qml` stay owned by Origami -- not moving to Ayame.
  They're not the problem (see "Why this isn't a Theme/Units problem"
  below).
- This is **not** a "move everything into Ayame" job. Ayame is one of
  several valid destinations (see next section) -- the fix is to stop
  Origami fighting the style system, not to make Origami depend on Ayame
  specifically.
- The `Label`/`Slider` name collision with Ayame's own `Label`/`Slider`
  (noted in the original audit) is real but explicitly deprioritized --
  handle it last, after the actual delegation work.

## Why this is a real, active mechanism (not a hypothetical)

`cettila/apps/desktop-qml/src/main.rs` (~line 163) sets
`QT_QUICK_CONTROLS_STYLE` from `origami_config::settings::load_style`
before `QGuiApplication` is constructed -- this is a real, live,
user-facing setting (SettingsPage.qml's appearance tab), defaulting to
`org.kde.breeze` (set in `nix/dev.nix`) when nothing is saved. Valid
values proven by `origami-kit/config/src/settings.rs`'s own round-trip
test include `"org.kde.desktop"`, `"Fusion"`, and `"Ayame"` (saving
`"la.cettila.Ayame"` normalizes to `"Ayame"` on load).

`ayame/crates/qml6`'s QML module is laid out exactly the way Qt Quick
Controls 2's custom-style convention expects: flat, QQC2-control-named
files (`Button.qml`, `Label.qml`, `CheckBox.qml`, `ComboBox.qml`, ...).
That's not a coincidence -- **Ayame is a real, swappable QQC2 style**,
selectable the same way Breeze or Fusion are.

Any QQC2 control that does *not* set its own `background:`/state-colored
properties automatically renders using whichever style is active. Origami
setting these explicitly means Origami's own look wins regardless of
which style the user picked -- the style selector is silently defeated
for anything built from Origami's widgets. That's the "上書きしてしまっ
ている" the user flagged. Fixing it means Origami's components should, by
default, render through the active style (Breeze, Fusion, or Ayame,
whichever is selected) the same way Ayame's own widgets and bare QQC2
controls already do.

## Why this isn't a Theme/Units problem

`Theme.qml` (`paletteFor()`, semantic positive/negative/neutral colors)
and `Units.qml` (spacing/sizing scale) aren't part of the style-fighting
problem -- they're used for legitimate things a QQC2 style has no opinion
on (Label's semantic color variants, layout spacing). They stay in
Origami untouched by this task.

## Inventory (audited 2026-08-14, whole `origami/qml` tree, 53 files total)

Two different categories -- treat them differently, don't lump them into
one mechanical pass.

### Category A -- plain QQC2 subclass with a `background:` override

Removing the override should be enough to let the active style take over,
same as Ayame's/bare QQC2's own controls. Lowest risk, do this first.

- `widgets/buttons/ActionButton.qml`
- `widgets/buttons/ActionButtonGroup.qml`
- `widgets/buttons/DropdownButton.qml`
- `widgets/buttons/HamburgerButton.qml`
- `widgets/buttons/ToggleButton.qml`
- `widgets/buttons/ToggleGroup.qml`
- `widgets/menus/ThemedMenu.qml`
- `widgets/menus/ThemedSubMenu.qml`
- `widgets/popups/ConfirmDialog.qml`
- `widgets/popups/IoErrorBanner.qml`
- `pane/ViewTypePickerButton.qml`
- `regions/header/HeaderMenuButton.qml`
- `regions/panel/CollapsiblePanel.qml`
- `views/Breadcrumb.qml`
- `views/CollapsibleTextField.qml`
- `views/FileTile.qml`

Each needs an individual look before deleting `background:` blindly --
some of these (`DropdownButton`, `HamburgerButton`, `ViewTypePickerButton`
at least) mix a real top-level QQC2 control's `background:` *with*
custom child chrome that belongs in Category B (see next). Splitting
those two concerns apart is part of the per-file work, not just a
one-line deletion.

### Category B -- custom composite widget, no single QQC2 control to delegate to

These hand-draw hover/press affordance `Rectangle`s as part of a larger
custom layout (tab chrome, breadcrumb segments, grouped button bars,
spinner buttons) that doesn't map onto one styleable QQC2 control.
Deleting the color logic here would just make the affordance disappear --
there's no active style standing by to replace it. Needs per-widget
judgment (rebuild the interactive piece atop a real QQC2 control so the
style applies, or at minimum re-source the hover/highlight colors from
the active style/Ayame's palette instead of Origami's own invented
values, so it's visually consistent even if not literally delegated).
Do this after Category A's pattern has proven out.

- `pane/groups/PaneTabHeader.qml`
- `views/Breadcrumb.qml` (segment button, separate from its own
  Category-A `background:` -- appears in both lists)
- `views/CollapsibleSection.qml`
- `views/CollapsibleTextField.qml` (separate hover affordance, also
  appears in Category A)
- `widgets/buttons/ToggleGroup.qml` (also in Category A -- same split
  as `DropdownButton`/`HamburgerButton`)
- `widgets/buttons/ActionButtonGroup.qml` (also in Category A)
- `widgets/buttons/ToggleButton.qml` (also in Category A)
- `widgets/buttons/DropdownButton.qml` (also in Category A)
- `widgets/buttons/HamburgerButton.qml` (also in Category A)
- `widgets/controls/ColorSwatch.qml`
- `widgets/controls/Slider.qml` (drag-handle pressed-state color)
- `widgets/inputs/NumberInput.qml` (spinner buttons)
- `pane/ViewTypePickerButton.qml` (also in Category A)
- `regions/header/HeaderMenuButton.qml` (also in Category A)
- `widgets/popups/IoErrorBanner.qml` (close button, also in Category A)

(Files with `hovered`/`pressed` usage that turned out to be unrelated to
appearance -- e.g. tooltip visibility toggles -- were excluded from both
lists; not every `hovered` hit is a style-fighting bug.)

## Steps

- [x] Phase 1 -- Category A, all 16 files triaged one at a time (done
      2026-08-14). Outcome: 6 files edited (background removed, 3 of
      those replaced the lost affordance with `checked: <popup
      visible>`), 4 reclassified to Category B (structural
      grouping/shape had no style to delegate to), 6 left unchanged with
      documented reasoning (legitimate context-matching or
      safety-semantic overrides, not style-fighting). Per-file detail
      below.
  - [x] `widgets/buttons/ActionButton.qml` -- removed the `background:`
        Rectangle and the `_borderColor` property that only fed its
        border color. Kept `_colors`/`_textColor`/`contentItem` (the
        `destructive` red-text variant is semantic, not style-fighting --
        same reasoning as `Label.qml`'s positive/negative/neutral
        colors). Kept `implicitHeight`/`implicitWidth`/`opacity`/
        `hoverEnabled`/tooltip -- sizing and disabled-opacity weren't
        part of what was asked (background/color/hover), left untouched
        to avoid scope creep.
  - [x] `widgets/buttons/ActionButtonGroup.qml` -- reclassified to
        Category B, not touched in this pass. Its `background:` isn't a
        plain style override: the per-segment corner rounding (only
        first/last segment rounded) and the 1px inter-segment separator
        are what make this a *grouped/segmented* row at all -- no QQC2
        style has an opinion on that shape, so there's nothing to
        delegate to. The outer border `Rectangle` (container chrome, not
        a QQC2 control) is the same story. Revisit in the Category B
        phase.
  - [x] `widgets/buttons/DropdownButton.qml` -- removed the `background:`
        override. Its `menu.visible ? highlightColor : ...` fill was
        replaced with `checked: menu.visible` (not `checkable` -- nothing
        should auto-toggle it) instead of dropping the affordance: QQC2
        styles already render a checked tool/button distinctly, so the
        "popup is open" cue survives without this component painting
        anything itself. Same technique likely applies to
        `HamburgerButton.qml`/`HeaderMenuButton.qml`/
        `ViewTypePickerButton.qml` below -- same `menu.visible`/
        `popup.visible` -> `highlightColor` pattern.
  - [x] `widgets/buttons/HamburgerButton.qml` -- same shape as
        `DropdownButton.qml`, same fix: `background:` removed,
        `checked: menu.visible` added in its place.
  - [x] `widgets/buttons/ToggleButton.qml` -- reclassified to Category B,
        not touched. Same shape as `ActionButtonGroup.qml`: main toggle +
        optional details-popup button sit in a joined-corner pair with a
        hairline separator; the `background:` overrides are what make it
        read as one joined control, not a per-control style override.
  - [x] `widgets/buttons/ToggleGroup.qml` -- reclassified to Category B,
        not touched. Same segmented-group shape as
        `ActionButtonGroup.qml`, plus an animated sliding
        `selectionIndicator` Rectangle -- all structural, no style
        equivalent to delegate to.
  - [x] `widgets/menus/ThemedMenu.qml` -- partial. Removed the menu
        panel's own `background:` (plain popup chrome, no grouping) and
        the generic `wrapItem` delegate's `background:` (driven only by
        native `highlighted`, zero info loss). Left the `Instantiator`'s
        `QQC2.MenuItem` background alone -- it also encodes `_selected`
        ("this is the current value" from external data), which has no
        risk-free native equivalent (`checked`+`checkable` would work in
        principle but `checkable` auto-toggles `checked` on click,
        severing the live `_selected` binding on first click -- would
        need a real rework of the click/selection interaction, not a
        mechanical delete). Left a comment explaining why in the file.
  - [x] `widgets/menus/ThemedSubMenu.qml` -- same treatment as
        `ThemedMenu.qml`: removed the panel's own `background:`, left the
        single `MenuItem` delegate's `background:` alone (same
        `_selected`-vs-`checked` conflict, commented why).
  - [x] `widgets/popups/ConfirmDialog.qml` -- no change needed. The
        dialog's own `QQC2.Popup` background was already un-overridden
        (already style-delegated). The one `background:` present is on
        the confirm `ActionButton` instance, applying a red fill only
        when `isDestructive` -- kept, same reasoning as `ActionButton`'s
        destructive text color: no QQC2 style has a "danger" role to
        delegate to, and this is safety-relevant (signals an
        irreversible action), not idle/hover-chrome style-fighting.
  - [x] `widgets/popups/IoErrorBanner.qml` -- no change. The root
        `Rectangle`'s error-tint `color` isn't a QQC2 override at all
        (Rectangle has no style to delegate to). The close button's
        `background:` already carries an in-code comment explaining it's
        intentional (matches the banner's own red tint so a native gray
        hover fill doesn't look out of place on a colored strip) --
        can't verify visually in this environment either way (no
        GUI/screenshot verification per cettila's AGENTS.md rule), so
        left the existing, already-reasoned choice alone rather than
        guess.
  - [x] `pane/ViewTypePickerButton.qml` -- same fix as
        `DropdownButton.qml`/`HamburgerButton.qml`: `background:` removed,
        `checked: popup.visible` added in its place. Left its unrelated
        `_suppressReopen`/`onHoveredChanged` click-race guard untouched
        (behavior, not appearance).
  - [x] `regions/header/HeaderMenuButton.qml` -- reclassified to Category
        B, not touched. Its `leftRadius`/`rightRadius` are load-bearing:
        `HeaderMenuGroup.qml` sets them so a row of these buttons reads as
        one joined, rounded bar. `background:` is a single property --
        can't keep custom shaping while handing color/hover to the style,
        since setting *any* background item fully replaces the style's
        own delegate. Same structural-grouping blocker as
        `ActionButtonGroup.qml`.
  - [x] `regions/panel/CollapsiblePanel.qml` -- no change. `panelBody`'s
        `Rectangle` isn't a QQC2 override (it's the floating panel's own
        translucent surface, not a control). The collapsed-handle
        `IconButton`'s `background:` sets it to the same translucent
        `panelColor` as the panel body so the collapsed tab reads as an
        attached continuation of the panel -- a native opaque style
        background would look detached/wrong here. Same "match
        surrounding context color" precedent as `IoErrorBanner.qml`'s
        close button / `ConfirmDialog.qml`'s destructive button.
  - [x] `views/Breadcrumb.qml` -- removed the segment button's
        `background:` (plain hover-only fill, no grouping constraint
        unlike `ActionButtonGroup.qml`). Kept `contentItem`'s plain
        (non-hover-driven) text color.
  - [x] `views/CollapsibleTextField.qml` -- no change. `frame` is a plain
        `Rectangle` (the whole composite widget's own frame/background,
        not a QQC2 control) -- no style equivalent to delegate to, same
        as `ActionButtonGroup.qml`'s outer border. Both nested
        `QQC2.TextField`s set `background: null` deliberately (avoids a
        double border/fill nesting inside `frame`'s own chrome), not
        style-fighting. Text/placeholder colors are plain content color,
        not hover-driven -- already-established as fine.
  - [x] `views/FileTile.qml` -- no change. Its `background:` already
        carries a specific, well-reasoned design rationale in-code: the
        active style's default `ItemDelegate` background is an opaque
        row fill, which would paint over the grid view's own background
        -- wrong for an icon-grid tile. The override instead does
        transparent + hover outline + filled-only-when-selected,
        explicitly matching Dolphin's real icon-grid convention (as
        opposed to its list-row convention) -- this is opting out of a
        default that doesn't fit a grid-tile context, not reinventing
        Breeze for no reason. Kept.
- [ ] Phase 2 -- Category B: per-widget judgment call for each entry --
      rebuild atop a real QQC2 control where practical, otherwise
      re-source hover/highlight colors from the active
      style/Ayame instead of Origami's own invented palette values.
      Revisit this file's step list once Phase 1 is done and the pattern
      is clearer -- don't over-plan this phase up front.
- [ ] Phase 3 -- last: resolve the `Label`/`Slider` name collision with
      Ayame's own `Label`/`Slider` (rename Origami's, or Ayame's, or
      reconcile -- not decided yet, deliberately deferred).
- [ ] Phase 4 -- verify: `cargo check` (`nix develop --command cargo
      check -p origami -p origami-gallery`, and via the cettila workspace
      too since origami is consumed there) with no errors. Manually
      re-read every touched file for leftover dead code (unused
      `_colors`/`colorSet` properties whose only consumer was the deleted
      `background:` block, etc.) rather than trusting the compiler alone
      -- QML doesn't get the same dead-code warnings Rust does.

## Note on repo state while this was being audited

While auditing, `origami-frameworks/Cargo.toml` picked up `ayame` as a
real workspace member (`ayame -> ../ayame/crates/qml6` symlink) and
`origami-kit/origami-config` was renamed to `origami-kit/config` -- both
outside this task, presumably parallel work on making origami-frameworks
buildable standalone. Noted here so a resumed session isn't confused by
paths that don't match what an earlier version of this file might have
assumed.
