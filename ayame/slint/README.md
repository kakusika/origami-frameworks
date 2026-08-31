# ayame-slint

Ayame Design System library and components for [Slint](https://slint.dev/).

`ayame-slint` provides:
1. **`Tokens` global**: Design tokens for colors, spacing, corner radius, borders, and animations, dynamically resolved from `ayame-config` (`~/.config/ayamerc`).
2. **Standard UI Components**: `AppButton`, `ToggleSwitch`, `CheckBox`, `RadioButton`, `AppTextField`, `AppTextArea`, `OptionSlider`, `ProgressBar`, `Badge`, `Divider`, `Card`, `ButtonGroup`, `ToolTip`, `CollapsibleSection`, `DropdownButton`, `ColorSwatchRow`, `SidebarCategoryList`.
3. **Vendored Icons**: Monochrome SVG icons exposed through `Icons` global and `Icon` wrapper.

---

## Usage

### 1. In `Cargo.toml`
Add `ayame-slint` to dependencies and `ayame-slint-build` / `slint-build` to build dependencies:

```toml
[dependencies]
slint = "1.17"
ayame-slint = { git = "https://github.com/kakusika/ayame" }

[build-dependencies]
slint-build = "1.17"
ayame-slint-build = { git = "https://github.com/kakusika/ayame" }
```

### 2. In `build.rs`
Use `ayame_slint_build::configure` to register `@ayame` library paths:

```rust
fn main() {
    let config = ayame_slint_build::configure(slint_build::CompilerConfiguration::new());
    slint_build::compile_with_config("ui/app.slint", config).unwrap();
}
```

### 3. In `.slint` files
Import tokens and components directly:

```slint
import { Tokens } from "@ayame/tokens.slint";
import { AppButton, CheckBox, AppTextField, Card } from "@ayame/components.slint";
import { Icon, Icons } from "@ayame/icons.slint";

export component MyWidget inherits Rectangle {
    background: Tokens.background;

    Card {
        AppTextField {
            placeholder-text: "Enter name...";
        }
        AppButton {
            text: "Submit";
            primary: true;
        }
    }
}
```
