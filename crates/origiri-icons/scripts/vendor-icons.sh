#!/usr/bin/env bash
# Re-vendors the full Tabler Icons outline set into ui/icons/tabler/,
# patching stroke="currentColor" -> stroke="#000000" (see
# ui/icons/tabler/LICENSE.md for why).
# Re-run this whenever picking up a newer Tabler Icons release, then run
# `gen-icons-slint.js tabler` to regenerate ui/icons/tabler.slint's
# `TablerIcons` global.
set -euo pipefail

CRATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONS_DIR="$CRATE_DIR/ui/icons/tabler"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/tabler/tabler-icons.git "$TMP_DIR/repo" >/dev/null
git -C "$TMP_DIR/repo" sparse-checkout set icons/outline >/dev/null

commit="$(git -C "$TMP_DIR/repo" rev-parse HEAD)"
echo "vendoring from tabler/tabler-icons @ $commit"

mkdir -p "$ICONS_DIR"

# Keep LICENSE.md, drop every other existing vendored svg before re-vendoring
# so removed/renamed upstream icons don't linger.
find "$ICONS_DIR" -maxdepth 1 -name '*.svg' -delete

for src in "$TMP_DIR/repo/icons/outline"/*.svg; do
  name="$(basename "$src")"
  sed 's/stroke="currentColor"/stroke="#000000"/' "$src" >"$ICONS_DIR/$name"
done

count="$(find "$ICONS_DIR" -maxdepth 1 -name '*.svg' | wc -l)"
echo "vendored $count icons into $ICONS_DIR"
