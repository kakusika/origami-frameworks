use crate::palette::RgbColor;

/// No accent-color source wired up for this target yet -- only the
/// light/dark read (via `dark-light`, which does cover this target) is
/// available.
pub(crate) fn detect() -> Option<RgbColor> {
    None
}
