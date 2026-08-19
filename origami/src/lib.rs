pub mod cxxqt_object;
pub mod fs_entries;
pub mod fs_watch;
pub mod pane_tree;

pub use ayame::apply_theme;

#[used]
pub static KEEP_AYAME_ICONS_LINKED: &[(&str, &str)] = ayame::cxxqt_object::KEEP_AYAME_ICONS_LINKED;

pub fn apply_saved_theme_mode() {
    let vault_root = std::path::Path::new(origami_config::workspace::DEFAULT_VAULT_ROOT);
    let mode = origami_config::settings::load_theme_mode(vault_root);
    let accent = origami_config::settings::load_accent_color(vault_root);
    ayame::apply_theme(&mode, &accent);
}

pub fn apply_saved_ui_font() {
    let vault_root = std::path::Path::new(origami_config::workspace::DEFAULT_VAULT_ROOT);
    let family = origami_config::settings::load_ui_font_family(vault_root);
    let point_size = origami_config::settings::load_ui_font_point_size(vault_root);
    ayame::apply_ui_font(family.as_deref(), point_size.unwrap_or(0.0));
}
