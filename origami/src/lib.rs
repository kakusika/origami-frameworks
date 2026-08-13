pub mod cxxqt_object;
pub mod fs_entries;
pub mod fs_watch;
pub mod pane_tree;

pub use ayame::apply_theme_mode;

pub fn apply_saved_theme_mode() {
    let vault_root = std::path::Path::new(origami_config::workspace::DEFAULT_VAULT_ROOT);
    ayame::apply_theme_mode(&origami_config::settings::load_theme_mode(vault_root));
}

pub fn apply_saved_ui_font() {
    let vault_root = std::path::Path::new(origami_config::workspace::DEFAULT_VAULT_ROOT);
    let family = origami_config::settings::load_ui_font_family(vault_root);
    let point_size = origami_config::settings::load_ui_font_point_size(vault_root);
    ayame::apply_ui_font(family.as_deref(), point_size.unwrap_or(0.0));
}
