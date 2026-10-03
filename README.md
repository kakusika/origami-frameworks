# Origami Frameworks

Modular UI framework and component library built on Rust and Slint.

## Overview

Origami Frameworks provides a composable, high-performance UI foundation designed for desktop applications, featuring headless window/pane management, comprehensive design token theming, and Vulkan-accelerated rendering.

## Crates

### Core & UI
- **`origami`**: Reusable Slint UI widgets, layouts, panels, menus, and dialogs.
- **`origami-build`**: Build script helper for configuring Slint compilation and `@origami` resource paths.

### Origami Kit
- **`origami-kit/panes` (`origami-panes`)**: Headless workspace layout engine supporting nested splits, tabs, drawers, floating windows, and drag-and-drop docking geometry.
- **`origami-kit/theme` (`origami-theme`)**: Design tokens, color palettes, and theme mode resolvers.
- **`origami-kit/config` (`origami-config`)**: Application settings, session state, and vault workspace persistence.
- **`origami-kit/viewport` (`origami-viewport`)**: Hardware-accelerated offscreen Vulkan context and image rendering bridge for Slint viewports.
- **`origami-kit/views/richtext-flow` (`origami-richtext-flow`)**: Pure-Rust document model (blocks of styled text runs and atomic embedded elements) and line-breaking engine for mixed text + element content.
- **`origami-kit/views/richtext` (`origami-richtext`)**: `FlowView` Slint component embedding real widgets per element via `ComponentFactory`; ships `.slint` source only (see its README for why).

### Gallery
- **`origami-gallery`**: Interactive component gallery showcasing all widgets, pane configurations, and viewport renderers.

## Building and Running

### Prerequisites
- Rust stable (2024 edition)
- Wayland / X11 graphics libraries (Vulkan loader, libxkbcommon, fontconfig)
- Or use Nix: `nix develop`

### Run Gallery
```bash
cargo run -p origami-gallery
```

### Run Tests
```bash
cargo test --workspace
```
