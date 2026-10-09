use crate::palette::RgbColor;

/// Shells out to `defaults read -g AppleAccentColor` rather than binding
/// `CFPreferencesCopyAppValue`/Cocoa directly -- this is the one value we
/// need, it's a single cheap process spawn at startup, and it keeps this
/// feature free of an objc2/Foundation dependency for a one-shot read.
///
/// `AppleAccentColor` holds -1..6 for a named accent (Graphite through
/// Pink); the key is absent entirely when the user has "Multicolor"
/// selected, in which case there's no single accent to report.
pub(crate) fn detect() -> Option<RgbColor> {
    let output = std::process::Command::new("defaults")
        .args(["read", "-g", "AppleAccentColor"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let value: i32 = std::str::from_utf8(&output.stdout)
        .ok()?
        .trim()
        .parse()
        .ok()?;

    // Matched to the equivalent light-appearance `NSColor.systemXColor`
    // for each named accent swatch in System Settings > Appearance.
    let hex = match value {
        -1 => "#8E8E93", // Graphite
        0 => "#FF383C",  // Red
        1 => "#FF8D28",  // Orange
        2 => "#FFCC00",  // Yellow
        3 => "#34C759",  // Green
        4 => "#0088FF",  // Blue
        5 => "#CB30E0",  // Purple
        6 => "#FF2D55",  // Pink
        _ => return None,
    };
    RgbColor::from_hex(hex)
}
