use crate::palette::RgbColor;

/// `HKCU\Software\Microsoft\Windows\DWM\AccentColor` is a 32-bit ABGR
/// value (byte 0 = R, 1 = G, 2 = B, 3 = A) -- the same accent color shown
/// in Settings > Personalization > Colors.
pub(crate) fn detect() -> Option<RgbColor> {
    use winreg::RegKey;
    use winreg::enums::HKEY_CURRENT_USER;

    let dwm = RegKey::predef(HKEY_CURRENT_USER)
        .open_subkey("Software\\Microsoft\\Windows\\DWM")
        .ok()?;
    let abgr: u32 = dwm.get_value("AccentColor").ok()?;
    let r = (abgr & 0xFF) as u8;
    let g = ((abgr >> 8) & 0xFF) as u8;
    let b = ((abgr >> 16) & 0xFF) as u8;
    Some(RgbColor::new(r, g, b))
}
