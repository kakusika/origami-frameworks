# ayame-icons

Generic, freedesktop-named, tintable UI icons for this workspace's QML
apps (`ayame`, and sibling apps `../hime`, `../typedmark`, `../cettila`
that depend on this crate directly, without pulling in Ayame's own QQC2
style). Not app logos -- each app keeps its own logo in its own repo.

## Why

`QIcon::fromTheme()` resolution isn't guaranteed to hit a correctly
proportioned icon set outside a full desktop session (see
`crates/qml6/cpp/icon_theme.cpp`'s doc comment for the concrete symptom),
and doesn't work at all on Windows, which this workspace's apps need to
run on. This crate stops depending on OS icon-theme resolution: icons are
bundled as Qt resources and resolved by name directly, so rendering is
byte-identical regardless of platform, QQC2 style, or desktop config.

## Icon set

[Tabler Icons](https://github.com/tabler/tabler-icons) (MIT), `outline`
variant. Picked over Breeze Icons specifically because this package is
reused by apps that don't use Ayame's QQC2 style at all, and Tabler's
neutral outline style doesn't carry an OS-specific design identity the
way Breeze (KDE) or Fluent (Windows 11) do.

Only the subset of icons actually referenced across consumer apps is
vendored (`vendor/tabler-icons/outline/`), not the full ~5,900-icon
set -- see `vendor/tabler-icons/NOTICE.md` for exactly what was
vendored, from which commit, and under what license.

That inventory was built by grepping consumer QML for icon-name
literals, which missed icon names computed dynamically in Rust (e.g.
`origami-frameworks/origami/src/fs_entries.rs`'s extension -> icon-name
function, or `cettila`'s bookmarks-sidebar folder icons) -- several
were only caught by an icon rendering blank at runtime after step 6/7
removed the OS-theme-fallback stopgap. When adding a new consumer or a
new dynamically-generated icon name, grep the *implementation*, not
just literal QML, and check the name is in `src/mapping.rs` before
relying on it -- there is no fallback for a name that isn't.

Consumers use stable, freedesktop-style names (`document-new`,
`edit-delete`, ...); the mapping from those names to the underlying
Tabler filename is internal to this crate (`src/mapping.rs`) and
documented with rationale in `.agents/tasks/bundle-tabler-icons.md` in
the workspace root.

## Using this crate from a consumer app

Add it as a normal Cargo dependency -- the Qt resource
(`qrc:/cettila/icons/<name>.svg`) gets compiled and linked in via this
crate's own `build.rs`, no extra wiring needed in the consumer's
`build.rs`.

That said, a plain `Cargo.toml` dependency is **not enough by itself**:
if nothing in the consumer crate's Rust source actually references
`ayame_icons` (e.g. `ayame_icons::MAPPING`), rustc treats the crate as
unused and drops its rlib -- and with it, the linked-in Qt resource --
from the final binary entirely, even though `cargo build` succeeds
without any error or warning. `crates/qml6/src/cxxqt_object.rs` has a
`const _KEEP_AYAME_ICONS_LINKED = ayame_icons::MAPPING;` for exactly
this reason; any other consumer needs the same kind of token reference
somewhere in its own Rust source.
