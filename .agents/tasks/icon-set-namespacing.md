# origami-icons: namespace icon sets (Tabler isn't the only one forever)

## Why

`ui/icons/*.svg` is a flat directory and `ui/icons.slint` generates one flat
`Icons` global, both hardcoding "there is exactly one icon set" (Tabler).
Adding a second set later would mean either name collisions in the flat
directory, or a messy one-off restructure. Fix the namespacing now, before
more consumers (immermemo's icon picker / `@doc.icon` rendering work) lock
in `Icons.<slug>` as the call site shape.

Part of a larger cross-repo task (origami-icons here, then `@doc.icon`
rendering + note icons + an icon picker in immermemo) -- this file covers
only the origami-icons piece.

## Plan

- [ ] Move vendored svgs + LICENSE.md: `ui/icons/*.svg` -> `ui/icons/tabler/*.svg`,
      `ui/icons/LICENSE.md` -> `ui/icons/tabler/LICENSE.md`.
- [ ] `scripts/vendor-icons.sh`: vendor into `ui/icons/tabler/` instead of
      `ui/icons/`.
- [ ] `scripts/gen-icons-slint.js`: take a set name arg, read
      `ui/icons/<set>/*.svg`, write a fully-generated `ui/icons/<set>.slint`
      (`export global <Set>Icons { ... }`) instead of regex-replacing a
      block inside the hand-written file.
- [ ] `ui/icons.slint` becomes hand-written only: the `Icon` component plus
      `export { TablerIcons } from "icons/tabler.slint";` (one re-export
      line per set, added by hand when a set is added -- not worth
      automating for something this rare).
- [ ] Update every consumer of the old flat `Icons` global to `TablerIcons`:
      grep `Icons\.` and `import.*Icons` across origami, origami-mobile,
      and immermemo (separate repo/checkout).
- [ ] Build/check all affected crates (including immermemo, after bumping
      its git dependency pin) to confirm nothing still references the old
      name.

## Done

Fold anything worth keeping into a doc comment or commit message, then
delete this file.
