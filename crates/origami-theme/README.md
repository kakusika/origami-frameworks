# origami-theme

Origami's theme, as pure Rust with no UI-toolkit dependency:

- `palette` -- the light/dark presets and a registry of named color schemes
  (`palette::presets::SCHEMES`), plus the logic that composes a preset with
  an accent color into the full set of roles.
- `ThemeSettings` -- what an app chooses: palette variant, optional accent,
  corner radius, border width, animation speed, UI scale. Plain data; there
  is no settings file. An app that persists the user's choices builds a
  `ThemeSettings` from them at startup.
- `resolve(&ThemeSettings) -> ResolvedTheme` -- concrete color, shape,
  spacing and animation tokens. For Slint, push them onto the `Tokens`
  global from `origami-slint`'s `ui/tokens.slint`.

Folded in from what used to be the separate Ayame crates.

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
