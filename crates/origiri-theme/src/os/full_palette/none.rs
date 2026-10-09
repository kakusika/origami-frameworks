use crate::palette::PalettePreset;

/// No full-palette source wired up for this target -- only the accent
/// (`super::accent`) and light/dark read are available.
pub(crate) fn detect() -> Option<PalettePreset> {
    None
}
