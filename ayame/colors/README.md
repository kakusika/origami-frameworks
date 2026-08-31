# ayame-colors

Ayame's own `QPalette` color data: the light/dark presets that used to be
hardcoded `QColor` literals in `crates/qml6/cpp/theme_palette.cpp`, plus a
registry of named color schemes (see `src/presets.rs`) and the logic to
compose a chosen preset with a freely-picked accent color into the full set
of roles Qt needs. Pure Rust, no build.rs, no cxx-qt bridge -- consumed by
`crates/qml6`, which owns the actual FFI boundary into Qt.

## Color scheme credits

Every scheme in `presets::SCHEMES` besides Ayame's own is ported from a
third-party project's published palette. Only the numeric color values
were used (no source code); each is cited in `presets.rs` alongside the
exact upstream file/page it came from. Credited here per each project's
license terms:

| Scheme | Project | License |
| --- | --- | --- |
| TokyoNight | [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | Apache License 2.0 |
| Catppuccin | [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | MIT License |
| Flexoki | [kepano/flexoki](https://github.com/kepano/flexoki) ([stephango.com/flexoki](https://stephango.com/flexoki)) | MIT License |
