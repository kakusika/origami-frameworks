# Tabler Icons -- vendored subset

Source: https://github.com/tabler/tabler-icons
License: MIT (see `LICENSE` in this directory)
Vendored at commit: `183e715d5a81ba1959e285f69c08235fe34b04ce` (2026-08-16)
Variant: `outline` (thin-stroke, `stroke="currentColor"` -- tintable as-is)

Only the icons actually referenced by `ayame-icons`' name mapping are
vendored here (`outline/<tabler-name>.svg`), not the full ~5,900-icon set.
Each file is downloaded unmodified from the upstream repo at the commit
above -- to update, re-fetch the same paths at a newer commit and update
the commit hash here.

The freedesktop-style name -> Tabler filename mapping (which name in this
package resolves to which file here) lives in `../mapping.rs`, not in this
directory -- this directory only tracks what was vendored from upstream
and under what license, and stays a faithful, unmodified copy of upstream
so future updates are a plain re-fetch/diff.
