use crate::palette::RgbColor;

/// Same portal, same `read_one` shape `dark-light`'s own freedesktop
/// backend uses for `color-scheme` -- just a different key. Only GNOME
/// 47+ and KDE currently implement `accent-color`; anywhere else this
/// errors out and we report `None`, same as macOS's "Multicolor".
#[zbus::proxy(
    interface = "org.freedesktop.portal.Settings",
    default_service = "org.freedesktop.portal.Desktop",
    default_path = "/org/freedesktop/portal/desktop"
)]
trait Settings {
    fn read_one(&self, namespace: &str, key: &str) -> zbus::Result<zbus::zvariant::OwnedValue>;
}

pub(crate) fn detect() -> Option<RgbColor> {
    let connection = zbus::blocking::Connection::session().ok()?;
    let proxy = SettingsProxyBlocking::new(&connection).ok()?;
    let value = proxy
        .read_one("org.freedesktop.appearance", "accent-color")
        .ok()?;
    let (r, g, b): (f64, f64, f64) = value.try_into().ok()?;

    // Out-of-range components mean "unset", per the portal spec.
    let in_range = |c: f64| (0.0..=1.0).contains(&c);
    if !in_range(r) || !in_range(g) || !in_range(b) {
        return None;
    }
    Some(RgbColor::new(
        (r * 255.0).round() as u8,
        (g * 255.0).round() as u8,
        (b * 255.0).round() as u8,
    ))
}
