<!-- Generated from tmtroot/readme.tmt. Edit that, then `tomet export .`. -->

# Origiri Frameworks

Modular UI framework and component library built on Rust and Slint.

## Overview

Origiri Frameworks provides a composable, high-performance UI foundation designed for desktop applications, featuring headless window/pane management, comprehensive design token theming, and Vulkan-accelerated rendering.

## Crates

- **`crates/origiri`**: Reusable Slint UI widgets, layouts, panels, menus, and dialogs.
- **`crates/origiri-build`**: Build script helper for configuring Slint compilation and `@origiri` resource paths.
- **`crates/origiri-mobile`**: Touch-first Slint widgets, icons, and tokens for mobile apps -- `.slint` source only, no consumer in this repo yet.
- **`crates/origiri-panes`**: Headless workspace layout engine supporting nested splits, tabs, drawers, floating windows, and drag-and-drop docking geometry.
- **`crates/origiri-theme`**: Design tokens, color palettes, and theme mode resolvers.
- **`crates/origiri-config`**: Application settings, session state, and vault workspace persistence.
- **`crates/origiri-viewport`**: Hardware-accelerated offscreen Vulkan context and image rendering bridge for Slint viewports.
- **`crates/views/richtext-flow` (`origiri-richtext-flow`)**: Pure-Rust document model (blocks of styled text runs and atomic embedded elements) and line-breaking engine for mixed text + element content.
- **`crates/views/richtext` (`origiri-richtext`)**: `FlowView` Slint component embedding real widgets per element via `ComponentFactory`; ships `.slint` source only (see its README for why).

### Gallery

- **`origiri-gallery`**: Interactive component gallery showcasing all widgets, pane configurations, and viewport renderers.

## Building and Running

### Prerequisites

- Rust stable (2024 edition)
- Wayland / X11 graphics libraries (Vulkan loader, libxkbcommon, fontconfig)
- Or use Nix: `nix develop`

### Run Gallery

```bash
cargo run -p origiri-gallery
```

### Run Tests

```bash
cargo test --workspace
```

