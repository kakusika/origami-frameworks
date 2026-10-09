use crate::palette::{PalettePreset, RgbColor};

/// Parses `~/.config/kdeglobals` -- KDE/Qt's own INI-format color scheme
/// file, read directly rather than through Qt/KDE libraries. It's the one
/// place on Linux with a full *named* palette (not just an accent): every
/// desktop that themes Qt apps writes it (Plasma itself, `kde-gtk-config`
/// for GTK sync, and non-Plasma setups like NixOS's Stylix module that
/// theme Qt apps without running Plasma). No desktop-name check (e.g.
/// `XDG_CURRENT_DESKTOP`) -- a Hyprland+Stylix session has no Plasma
/// running but still writes a perfectly valid `kdeglobals`, so this just
/// tries the file and trusts whatever it finds.
///
/// GNOME/libadwaita has no equivalent: it hardcodes its own palette and
/// exposes only the accent (already covered by `super::accent`) and
/// light/dark, not a full set of named colors.
pub(crate) fn detect() -> Option<PalettePreset> {
    let path = directories::BaseDirs::new()?.config_dir().join("kdeglobals");
    let contents = std::fs::read_to_string(path).ok()?;

    let mut window = None;
    let mut window_text = None;
    let mut base = None;
    let mut alternate_base = None;
    let mut text = None;
    let mut button = None;
    let mut button_text = None;
    let mut tooltip_base = None;
    let mut tooltip_text = None;

    let mut section = String::new();
    for line in contents.lines() {
        let line = line.trim();
        if let Some(name) = line.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
            section = name.to_string();
            continue;
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        let Some(color) = parse_rgb(value) else {
            continue;
        };
        match (section.as_str(), key) {
            ("Colors:Window", "BackgroundNormal") => window = Some(color),
            ("Colors:Window", "ForegroundNormal") => window_text = Some(color),
            ("Colors:View", "BackgroundNormal") => base = Some(color),
            ("Colors:View", "BackgroundAlternate") => alternate_base = Some(color),
            ("Colors:View", "ForegroundNormal") => text = Some(color),
            ("Colors:Button", "BackgroundNormal") => button = Some(color),
            ("Colors:Button", "ForegroundNormal") => button_text = Some(color),
            ("Colors:Tooltip", "BackgroundNormal") => tooltip_base = Some(color),
            ("Colors:Tooltip", "ForegroundNormal") => tooltip_text = Some(color),
            _ => {}
        }
    }

    // No partial presets -- either every role was found, or we report
    // nothing and the caller falls back to a named preset.
    Some(PalettePreset {
        window: window?,
        window_text: window_text?,
        base: base?,
        alternate_base: alternate_base?,
        text: text?,
        button: button?,
        button_text: button_text?,
        tooltip_base: tooltip_base?,
        tooltip_text: tooltip_text?,
        // `[Colors:View] BackgroundAlternate` doubles as the raised-surface
        // shade -- `kdeglobals` has no separate role for it.
        light: alternate_base?,
    })
}

fn parse_rgb(value: &str) -> Option<RgbColor> {
    let mut parts = value.trim().split(',');
    let r = parts.next()?.trim().parse().ok()?;
    let g = parts.next()?.trim().parse().ok()?;
    let b = parts.next()?.trim().parse().ok()?;
    if parts.next().is_some() {
        return None;
    }
    Some(RgbColor::new(r, g, b))
}
