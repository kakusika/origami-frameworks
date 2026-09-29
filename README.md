# Origami Frameworks

Modular UI framework and component library built on Rust and Slint.

## Overview

Origami Frameworks provides a composable, high-performance UI foundation designed for desktop applications, featuring headless window/pane management, comprehensive design token theming, and Vulkan-accelerated rendering.

## Crates

### Core & UI
- **`origami-slint`**: Reusable Slint UI widgets, layouts, panels, menus, and dialogs.
- **`origami-slint-build`**: Build script helper for configuring Slint compilation and resource paths.

### Origami Kit
- **`origami-kit/panes` (`origami-panes`)**: Headless workspace layout engine supporting nested splits, tabs, drawers, floating windows, and drag-and-drop docking geometry.
- **`origami-kit/theme` (`origami-theme`)**: Design tokens, color palettes, and theme mode resolvers.
- **`origami-kit/config` (`origami-config`)**: Application settings, session state, and vault workspace persistence.
- **`origami-kit/viewport` (`origami-viewport`)**: Hardware-accelerated offscreen Vulkan context and image rendering bridge for Slint viewports.

### Gallery
- **`origami-gallery-slint`**: Interactive component gallery showcasing all widgets, pane configurations, and viewport renderers.

## Building and Running

### Prerequisites
- Rust stable (2024 edition)
- Wayland / X11 graphics libraries (Vulkan loader, libxkbcommon, fontconfig)
- Or use Nix: `nix develop`

### Run Gallery
```bash
cargo run -p origami-gallery-slint
```

### Run Tests
```bash
cargo test --workspace
```
