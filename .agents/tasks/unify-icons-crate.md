# Unify icons into `crates/origami-icons` (SVG method)

Decided with the user: standardize on the SVG/`Image`+`colorize` method
(desktop's existing approach) over mobile's `Path`+stroke-commands method,
because this is a general-purpose UI library -- future consumers need
access to a large existing icon corpus (Tabler has 5,800+), not a
hand-authored-per-icon path format. Once on one method, extract into a
shared `crates/origami-icons` crate consumed by both `crates/origami` and
`crates/origami-mobile` (mirrors how `origami-theme` is the single shared
source for color tokens).

## Icon set (30 total)

Reused from `crates/origami/ui/icons/*.svg` (already vendored, just
moved), canonical name wins where mobile had a different name for the
same icon:
`check`, `chevron-down` (was mobile `down`), `chevron-right` (was mobile
`forward`), `external-link`, `file`, `folder`, `grip-vertical`,
`maximize`, `menu-2` (was mobile `menu`), `minimize`, `minus`, `plus`,
`switch-horizontal`, `x` (was mobile `close`).

Newly fetched from `https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/<name>.svg`
(same MIT license as the existing vendored set, same outline/24x24 style,
saved to `/tmp/tabler_fetch/`), naming follows Tabler's own slug (not
mobile's old semantic `Shapes` name):
`chevron-left` (was `back`), `chevron-up` (was `up`), `arrow-back-up`
(was `undo`), `arrow-forward-up` (was `redo`), `refresh` (was `sync`),
`link`, `settings`, `search`, `home`, `files`, `note`, `info-circle`
(was `properties`), `copy`, `history`, `cloud`, `alert-triangle` (was
`alert`).

## Steps

- [x] Create `crates/origami-icons/{Cargo.toml,build.rs,src/lib.rs}`
      (same shape as `crates/origami`: `links = "origami_icons"`, no
      deps -- note `src/lib.rs` is required even though empty-ish, Cargo
      won't accept a library member with no target at all; missed this
      at first, caught by a real build failure).
- [x] Create `crates/origami-icons/ui/icons/*.svg` + `LICENSE.md`: moved
      the 14 existing files from `crates/origami/ui/icons/`, added the
      16 newly-fetched files (kept Tabler's `<!-- tags... -->` comment
      header -- the existing vendored files keep it too, so stripping it
      would have been an inconsistency; `stroke="currentColor"` ->
      `stroke="#000000"` as before).
- [x] Create `crates/origami-icons/ui/icons.slint`: `Icon` component
      (`inherits Image`, byte-identical to the old one) + `Icons` global
      with all 30 `@image-url("icons/<name>.svg")` entries.
- [x] `crates/origami/ui/icons.slint` + `icons/`: deleted; updated all 17
      `.slint` files under `crates/origami/ui/` that imported
      `Icon`/`Icons` to import from `@origami-icons/icons.slint`.
      Also found and fixed 2 raw `@image-url("icons/check.svg")` /
      `@image-url("icons/chevron-down.svg")` literals in
      `components.slint` that bypassed the `Icons` global entirely (a
      pre-existing inconsistency, not something this task introduced,
      but it broke once the files moved) -- changed to `Icons.check` /
      `Icons.chevron-down`.
- [x] `crates/origami-mobile/ui/icons.slint`: deleted. Updated
      `components.slint`'s import and every `Icon`/`Shapes.*` usage to
      `Icon`/`Icons.*`: renamed the `shape: string` properties on
      `IconButton`/`BubbleButton` to `icon: image` (matching desktop's
      `action_button.slint` convention) and `BubbleChip`'s `icon: string
      = ""` to `icon: image` (empty-check changed from `!= ""` to
      `.width > 0`); `Icon { shape: ...; tint: ...; }` -> `Icon { source:
      ...; color: ...; }` everywhere (including `animate tint` ->
      `animate color`); `Shapes.undo/redo/plus` -> `Icons.arrow-back-up/
      arrow-forward-up/plus`.
- [x] `origami-gallery/ui/mobile_page.slint`: updated its `Shapes.*`
      references and `shape:`/`icon: Shapes.x` props to the new
      `Icons.*`/`icon: Icons.x` names and import.
- [x] Root `Cargo.toml`: added `crates/origami-icons` to
      `[workspace.members]` and `[workspace.dependencies]`.
- [x] Confirmed `crates/origami`/`crates/origami-mobile` don't need an
      `origami-icons` Cargo dependency themselves (`DEP_<LINKS>_UI_DIR`
      only propagates to *direct* dependents' build scripts, and neither
      crate's own `build.rs` calls `slint_build::compile()`).
- [x] `crates/origami-build/src/lib.rs`: added `icons_ui_dir()` --
      **hard-required** (panics if missing), unlike `mobile_ui_dir()`'s
      soft-optional `None`, because `origami`'s own `.slint` now
      unconditionally imports `@origami-icons`, so anything depending on
      `origami` needs it too, same as `origami` itself.
- [x] `origami-gallery/Cargo.toml`: added `origami-icons` dependency.
- [x] `cargo build --workspace` / `cargo test --workspace` pass --
      verified with the real exit code checked directly (not through a
      `| tail` pipe, which silently reports `tail`'s exit code instead of
      cargo's and masked the first two real failures above).
- [x] Ran the gallery binary itself (not just compiled) to confirm it
      launches cleanly with the renamed icons across every tab.
- [ ] Commit (exclude any concurrent `crates/views/richtext*` changes
      the user is making separately). Push pending confirmation.

## Found during this task: immermemo's `apps/slint` UI breaks on next update

`immermemo/apps/slint/ui/**` (10 files: `components.slint`,
`screens/{home,search,files,editor}.slint`,
`sheets/{history,vault_history,conflict,vault,settings}.slint`) uses
origami-mobile's old `Shapes.*` API directly, 58 call sites across ~20
distinct names. Its `Cargo.lock` is pinned to `c97ebd7` (before this
change), so nothing breaks *yet* -- but the next `cargo update -p
origami-mobile` there will break the build. Not fixed here; flagged to
the user as a cross-repo follow-up, same shape as the earlier
`origami-panes` nidi/mumeum follow-up this session.
