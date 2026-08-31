//! Load/save small app-wide UI preferences under a vault's own namespace
//! subfolder (see `crate::identity`; `.cettila` for cettila itself).
//! Currently just the chosen QQC2 style name (see the settings screen's
//! "外観" category). Kept separate from `workspace.rs` since it has
//! nothing to do with the pane layout, but follows the same shape: one
//! opaque TOML file, vault-root relative. Transient "last used directory"
//! state lives in `cache.rs` instead, not here -- see that module for the
//! reasoning.

use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

pub fn settings_path(vault_root: &Path) -> PathBuf {
    vault_root
        .join(&crate::identity::app_identity().vault_namespace)
        .join("settings.toml")
}

/// Where the precomputed background-effect result (see
/// `cettila-view-settings`'s `background_effects` module) is written to and
/// `main.qml`'s background `Image` loads from. A single fixed filename --
/// only one background image/effect combination is ever active at once,
/// so there's no need for content-addressed caching.
pub fn background_cache_path(vault_root: &Path) -> PathBuf {
    vault_root
        .join(&crate::identity::app_identity().vault_namespace)
        .join("cache")
        .join("background.png")
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct Settings {
    #[serde(skip_serializing_if = "Option::is_none")]
    style: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    status_bar_visible: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    status_bar_refresh_ms: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    editor_font_point_size: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    editor_show_line_numbers: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    corner_radius: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    border_width: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    theme_mode: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    accent_color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ui_font_family: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ui_font_point_size: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    network_allowed: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    layout_locked: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    resize_locked: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    bookmarks: Option<Vec<BookmarkEntry>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    background_image_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    background_pane_opacity: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    background_effect: Option<BackgroundEffect>,
    #[serde(skip_serializing_if = "Option::is_none")]
    explorer_alternating_row_colors: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    animation_speed: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    animations_enabled: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ui_scale: Option<f64>,
}

/// Precomputed background-image effect + every effect's parameters (only
/// one effect is active at a time -- see `kind` -- so unused fields are
/// simply ignored rather than this being a tagged union; mirrors
/// `cettila-view-settings`'s `background_effects::EffectParams`
/// field-for-field, kept as a separate type since that crate can't depend
/// on this one's serde/TOML shape). `kind` is one of "none" (default),
/// "blur", "voronoi", "pixelate", "grayscale", "sepia", "invert",
/// "brightness_contrast", "posterize", "vignette", "noise", "duotone",
/// "hue_rotate", "edge_detect" -- see `SettingsPage.qml`'s effect catalog
/// for the Japanese labels.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct BackgroundEffect {
    pub kind: String,
    pub blur_strength: f64,
    pub voronoi_cells: u32,
    pub pixelate_block: u32,
    pub brightness: f64,
    pub contrast: f64,
    pub posterize_levels: u32,
    pub vignette_strength: f64,
    pub noise_amount: f64,
    pub duotone_preset: String,
    pub hue_rotate_degrees: f64,
}

impl Default for BackgroundEffect {
    fn default() -> Self {
        Self {
            kind: "none".to_string(),
            blur_strength: 8.0,
            voronoi_cells: 120,
            pixelate_block: 16,
            brightness: 0.0,
            contrast: 0.0,
            posterize_levels: 4,
            vignette_strength: 50.0,
            noise_amount: 20.0,
            duotone_preset: "blue_orange".to_string(),
            hue_rotate_degrees: 0.0,
        }
    }
}

/// One user-added Explorer bookmark (see `load_bookmarks`/`save_bookmarks`
/// below). `path` is always absolute; `name` is whatever the user typed
/// when adding it (not derived from the path, so a bookmark can be
/// relabeled without pointing anywhere new -- though nothing exposes a
/// rename yet, only add/remove).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BookmarkEntry {
    pub name: String,
    pub path: String,
}

fn load(vault_root: &Path) -> Settings {
    let path = settings_path(vault_root);
    match fs::read_to_string(&path) {
        Ok(content) => toml::from_str(&content).unwrap_or_default(),
        Err(_) => Settings::default(),
    }
}

fn save(vault_root: &Path, settings: &Settings) -> io::Result<()> {
    let toml = toml::to_string_pretty(settings)
        .map_err(|err| io::Error::new(io::ErrorKind::InvalidData, err))?;
    let path = settings_path(vault_root);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, toml)
}

/// The QQC2 style name the user picked in the settings screen, or `None` if
/// they haven't chosen one yet (in which case the process falls back to
/// `QT_QUICK_CONTROLS_STYLE`/the platform default).
pub fn load_style(vault_root: &Path) -> Option<String> {
    load(vault_root).style.map(|s| {
        if s == "la.cettila.Ayame" {
            "Ayame".to_string()
        } else {
            s
        }
    })
}

/// Persists the chosen style name. Takes effect on the next launch only --
/// QQC2's style is fixed for the lifetime of the process.
pub fn save_style(vault_root: &Path, style: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    let normalized = if style == "la.cettila.Ayame" {
        "Ayame"
    } else {
        style
    };
    settings.style = Some(normalized.to_string());
    save(vault_root, &settings)
}

/// Whether the bottom status bar (FPS/CPU/memory, see
/// `cettila-view-origami`'s `StatusBar.qml`) is shown. Like `load_style`,
/// only read once at process startup -- a pick made in the settings screen
/// takes effect on the next launch.
pub fn load_status_bar_visible(vault_root: &Path) -> bool {
    load(vault_root).status_bar_visible.unwrap_or(true)
}

pub fn save_status_bar_visible(vault_root: &Path, visible: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.status_bar_visible = Some(visible);
    save(vault_root, &settings)
}

/// How often (milliseconds) the status bar re-samples CPU/memory and
/// recomputes FPS.
pub fn load_status_bar_refresh_ms(vault_root: &Path) -> u32 {
    load(vault_root).status_bar_refresh_ms.unwrap_or(1000)
}

pub fn save_status_bar_refresh_ms(vault_root: &Path, ms: u32) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.status_bar_refresh_ms = Some(ms);
    save(vault_root, &settings)
}

/// Text editor font size, in points.
pub fn load_editor_font_point_size(vault_root: &Path) -> f64 {
    load(vault_root).editor_font_point_size.unwrap_or(11.0)
}

pub fn save_editor_font_point_size(vault_root: &Path, size: f64) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.editor_font_point_size = Some(size);
    save(vault_root, &settings)
}

/// Whether the text editor shows a line-number gutter.
pub fn load_editor_show_line_numbers(vault_root: &Path) -> bool {
    load(vault_root).editor_show_line_numbers.unwrap_or(false)
}

pub fn save_editor_show_line_numbers(vault_root: &Path, show: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.editor_show_line_numbers = Some(show);
    save(vault_root, &settings)
}

/// The Origami component library's corner-radius preset, one of
/// `"circle"`/`"large"`/`"medium"`/`"small"`/`"disabled"` (see
/// `cettila-view-origami`'s `Units.qml`). Defaults to `"small"`, matching
/// the fixed 4px radius `Units.cornerRadius` used before this setting
/// existed.
pub fn load_corner_radius(vault_root: &Path) -> String {
    load(vault_root)
        .corner_radius
        .unwrap_or_else(|| "small".to_string())
}

/// Persists the chosen corner-radius preset. Unlike `style`, this is
/// applied live by `Units.qml` -- no restart required.
pub fn save_corner_radius(vault_root: &Path, preset: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.corner_radius = Some(preset.to_string());
    save(vault_root, &settings)
}

/// The Origami component library's border-width preset, one of
/// `"thin"`/`"default"`/`"thick"` (see `cettila-view-origami`'s
/// `Units.qml`). Defaults to `"default"`, matching the fixed 1px width
/// used before this setting existed.
pub fn load_border_width(vault_root: &Path) -> String {
    load(vault_root)
        .border_width
        .unwrap_or_else(|| "default".to_string())
}

/// Persists the chosen border-width preset. Like `corner_radius`, this is
/// applied live by `Units.qml` -- no restart required.
pub fn save_border_width(vault_root: &Path, preset: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.border_width = Some(preset.to_string());
    save(vault_root, &settings)
}

/// The color scheme mode: `"system"` (follow the desktop/platform palette),
/// `"light"`, or `"dark"`. Defaults to `"system"`. Unlike `style`, this is
/// applied live -- see `cettila-view-origami`'s `ThemeSettings`/
/// `cpp/theme_palette.cpp`, which overrides `QGuiApplication`'s palette
/// directly, so a pick here takes effect immediately without a restart.
pub fn load_theme_mode(vault_root: &Path) -> String {
    load(vault_root)
        .theme_mode
        .unwrap_or_else(|| "system".to_string())
}

pub fn save_theme_mode(vault_root: &Path, mode: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.theme_mode = Some(mode.to_string());
    save(vault_root, &settings)
}

/// The user's freely-chosen accent color for Ayame's own palette, as a
/// `"#RRGGBB"` hex string -- see `ThemeSettings`/`ayame::apply_theme`/
/// `ayame-colors`, which compose it with the `theme_mode` preset into
/// Ayame's `QGuiApplication` palette. Only meaningful while `theme_mode` is
/// `"light"`/`"dark"` *and* Ayame is the active QQC2 style (see `style`);
/// ignored otherwise -- no override is attempted for other styles. Defaults
/// to Ayame's historical fixed accent, `"#3daee9"`. Like `theme_mode`,
/// applied live -- no restart required.
pub fn load_accent_color(vault_root: &Path) -> String {
    load(vault_root)
        .accent_color
        .unwrap_or_else(|| "#3daee9".to_string())
}

pub fn save_accent_color(vault_root: &Path, hex: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.accent_color = Some(hex.to_string());
    save(vault_root, &settings)
}

/// App-wide UI font family, or `None` to use the platform default. Like
/// `style`, this only takes effect on the next launch --
/// `QGuiApplication::setFont()` (see `cettila-view-origami`'s
/// `apply_saved_ui_font()`/`cpp/font_query.cpp`) only affects the default
/// font of items created after it's called, and it's applied right after
/// `QGuiApplication` is constructed, before the QML engine loads anything.
pub fn load_ui_font_family(vault_root: &Path) -> Option<String> {
    load(vault_root).ui_font_family
}

pub fn save_ui_font_family(vault_root: &Path, family: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.ui_font_family = Some(family.to_string());
    save(vault_root, &settings)
}

/// App-wide UI font point size, or `None` to use the platform default.
/// Same next-launch-only caveat as `ui_font_family`.
pub fn load_ui_font_point_size(vault_root: &Path) -> Option<f64> {
    load(vault_root).ui_font_point_size
}

pub fn save_ui_font_point_size(vault_root: &Path, size: f64) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.ui_font_point_size = Some(size);
    save(vault_root, &settings)
}

/// Whether the app may make outbound network requests at all (e.g.
/// `cettila-view-map`'s upcoming OSM tile downloads). Defaults to `false`
/// -- network access is opt-in, not assumed just because a feature could
/// use it. Unlike `style`/`ui_font_family`, this is meant to be read fresh
/// immediately before every network attempt (not just once at startup),
/// so a pick made in the settings screen takes effect right away with no
/// restart needed.
pub fn load_network_allowed(vault_root: &Path) -> bool {
    load(vault_root).network_allowed.unwrap_or(false)
}

pub fn save_network_allowed(vault_root: &Path, allowed: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.network_allowed = Some(allowed);
    save(vault_root, &settings)
}

/// Whether the pane layout is locked against drag-to-move (tab switching
/// stays available) and the compact tab-header grip is hidden. Like
/// `network_allowed`, meant to be read fresh right before use so a toggle
/// takes effect immediately, with no restart needed.
pub fn load_layout_locked(vault_root: &Path) -> bool {
    load(vault_root).layout_locked.unwrap_or(false)
}

pub fn save_layout_locked(vault_root: &Path, locked: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.layout_locked = Some(locked);
    save(vault_root, &settings)
}

/// Whether split-divider resizing is locked. Independent of
/// `layout_locked` -- either can be on without the other. Same
/// read-fresh-before-use caveat as `load_layout_locked`.
pub fn load_resize_locked(vault_root: &Path) -> bool {
    load(vault_root).resize_locked.unwrap_or(false)
}

pub fn save_resize_locked(vault_root: &Path, locked: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.resize_locked = Some(locked);
    save(vault_root, &settings)
}

/// User-added Explorer bookmarks (name + absolute path), in display/add
/// order. Empty until the user adds any via Explorer's bookmarks sidebar.
/// Distinct from that sidebar's own "storage" category (Home/Pictures/...),
/// which is resolved fresh from `directories::UserDirs` every time rather
/// than persisted here.
pub fn load_bookmarks(vault_root: &Path) -> Vec<BookmarkEntry> {
    load(vault_root).bookmarks.unwrap_or_default()
}

pub fn save_bookmarks(vault_root: &Path, bookmarks: &[BookmarkEntry]) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.bookmarks = if bookmarks.is_empty() {
        None
    } else {
        Some(bookmarks.to_vec())
    };
    save(vault_root, &settings)
}

/// The absolute path to the image the user picked as the app background
/// (`SettingsPage.qml`'s "外観" -> "背景画像" section), or `None` if unset.
/// Applied live -- see `cettila-view-settings`'s `Background.qml` singleton,
/// which pushes into `cettila-view-origami`'s `PaneBackdrop.qml`, which
/// every `PaneLeaf.qml` background and `main.qml`'s own window background
/// bind to directly.
pub fn load_background_image_path(vault_root: &Path) -> Option<String> {
    load(vault_root).background_image_path
}

pub fn save_background_image_path(vault_root: &Path, path: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.background_image_path = Some(path.to_string());
    save(vault_root, &settings)
}

/// Clears the background image (falls back to no background, panes back to
/// fully opaque).
pub fn clear_background_image_path(vault_root: &Path) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.background_image_path = None;
    save(vault_root, &settings)
}

/// How opaque (0.0-1.0) each pane's own background is drawn when a
/// background image is set -- lower values let more of the image show
/// through the pane content areas. Meaningless (and ignored) while no
/// background image is set, since `PaneLeaf.qml` stays fully opaque in
/// that case regardless of this value. Defaults to `0.85`.
pub fn load_background_pane_opacity(vault_root: &Path) -> f64 {
    load(vault_root).background_pane_opacity.unwrap_or(0.85)
}

pub fn save_background_pane_opacity(vault_root: &Path, opacity: f64) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.background_pane_opacity = Some(opacity.clamp(0.0, 1.0));
    save(vault_root, &settings)
}

/// The currently configured background effect + its parameters, or
/// `BackgroundEffect::default()` (kind "none") if never set.
pub fn load_background_effect(vault_root: &Path) -> BackgroundEffect {
    load(vault_root).background_effect.unwrap_or_default()
}

pub fn save_background_effect(vault_root: &Path, effect: &BackgroundEffect) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.background_effect = Some(effect.clone());
    save(vault_root, &settings)
}

/// Whether `cettila-view-explorer`'s tree view (`ExplorerTree.qml`) shades
/// alternating rows, Dolphin/VS Code style. Defaults to `true`. Like
/// `corner_radius`/`border_width`, applied live -- see `Units.qml`'s
/// `explorerAlternatingRows`, which seeds from this and can flip it without
/// a restart.
pub fn load_explorer_alternating_row_colors(vault_root: &Path) -> bool {
    load(vault_root)
        .explorer_alternating_row_colors
        .unwrap_or(true)
}

pub fn save_explorer_alternating_row_colors(vault_root: &Path, enabled: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.explorer_alternating_row_colors = Some(enabled);
    save(vault_root, &settings)
}

/// The app-wide animation-speed preset, one of `"slow"`/`"normal"`/`"fast"`
/// (see `cettila-view-origami`'s `Units.qml`, which maps this onto a
/// duration multiplier applied to every `Units.veryShortDuration`/
/// `shortDuration`/`longDuration`/`veryLongDuration` consumer). Defaults to
/// `"normal"` (multiplier 1.0, matching every duration constant's value
/// before this setting existed).
pub fn load_animation_speed(vault_root: &Path) -> String {
    load(vault_root)
        .animation_speed
        .unwrap_or_else(|| "normal".to_string())
}

/// Persists the chosen animation-speed preset. Like `corner_radius`, this is
/// applied live by `Units.qml` -- no restart required.
pub fn save_animation_speed(vault_root: &Path, preset: &str) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.animation_speed = Some(preset.to_string());
    save(vault_root, &settings)
}

/// Whether app-wide UI animations (see `animation_speed` above) run at all.
/// Defaults to `true`. When `false`, `Units.qml` collapses every duration
/// constant to 0 so a `Behavior`/`NumberAnimation` bound to it applies its
/// target value immediately instead of animating -- distinct from
/// `animation_speed`, which only changes how fast an animation plays, not
/// whether it plays.
pub fn load_animations_enabled(vault_root: &Path) -> bool {
    load(vault_root).animations_enabled.unwrap_or(true)
}

pub fn save_animations_enabled(vault_root: &Path, enabled: bool) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.animations_enabled = Some(enabled);
    save(vault_root, &settings)
}

/// App-wide UI scale multiplier, applied by `cettila-view-origami`'s
/// `Units.qml` to `gridUnit` (and everything derived from it: spacing,
/// control heights, icon sizes). Defaults to `1.0` -- no scaling, matching
/// every size constant's value before this setting existed.
pub fn load_ui_scale(vault_root: &Path) -> f64 {
    load(vault_root).ui_scale.unwrap_or(1.0)
}

/// Persists the chosen UI scale, clamped to a sane range. Like
/// `corner_radius`/`border_width`, applied live by `Units.qml` -- no
/// restart required.
pub fn save_ui_scale(vault_root: &Path, scale: f64) -> io::Result<()> {
    let mut settings = load(vault_root);
    settings.ui_scale = Some(scale.clamp(0.5, 2.0));
    save(vault_root, &settings)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(label: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "cettila-config-settings-test-{label}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn round_trips_style_through_toml_on_disk() {
        let dir = temp_dir("roundtrip");

        assert_eq!(load_style(&dir), None);

        save_style(&dir, "org.kde.desktop").unwrap();
        assert_eq!(load_style(&dir), Some("org.kde.desktop".to_string()));

        save_style(&dir, "Fusion").unwrap();
        assert_eq!(load_style(&dir), Some("Fusion".to_string()));

        save_style(&dir, "la.cettila.Ayame").unwrap();
        assert_eq!(load_style(&dir), Some("Ayame".to_string()));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_status_bar_and_editor_settings_through_toml_on_disk() {
        let dir = temp_dir("status-bar-editor-roundtrip");

        assert!(load_status_bar_visible(&dir));
        assert_eq!(load_status_bar_refresh_ms(&dir), 1000);
        assert_eq!(load_editor_font_point_size(&dir), 11.0);
        assert!(!load_editor_show_line_numbers(&dir));

        save_status_bar_visible(&dir, false).unwrap();
        save_status_bar_refresh_ms(&dir, 2000).unwrap();
        save_editor_font_point_size(&dir, 14.0).unwrap();
        save_editor_show_line_numbers(&dir, true).unwrap();

        assert!(!load_status_bar_visible(&dir));
        assert_eq!(load_status_bar_refresh_ms(&dir), 2000);
        assert_eq!(load_editor_font_point_size(&dir), 14.0);
        assert!(load_editor_show_line_numbers(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_corner_radius_through_toml_on_disk() {
        let dir = temp_dir("corner-radius-roundtrip");

        assert_eq!(load_corner_radius(&dir), "small");

        save_corner_radius(&dir, "circle").unwrap();
        assert_eq!(load_corner_radius(&dir), "circle");

        save_corner_radius(&dir, "disabled").unwrap();
        assert_eq!(load_corner_radius(&dir), "disabled");

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_border_width_through_toml_on_disk() {
        let dir = temp_dir("border-width-roundtrip");

        assert_eq!(load_border_width(&dir), "default");

        save_border_width(&dir, "thin").unwrap();
        assert_eq!(load_border_width(&dir), "thin");

        save_border_width(&dir, "thick").unwrap();
        assert_eq!(load_border_width(&dir), "thick");

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_theme_mode_through_toml_on_disk() {
        let dir = temp_dir("theme-mode-roundtrip");

        assert_eq!(load_theme_mode(&dir), "system");

        save_theme_mode(&dir, "dark").unwrap();
        assert_eq!(load_theme_mode(&dir), "dark");

        save_theme_mode(&dir, "light").unwrap();
        assert_eq!(load_theme_mode(&dir), "light");

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_accent_color_through_toml_on_disk() {
        let dir = temp_dir("accent-color-roundtrip");

        assert_eq!(load_accent_color(&dir), "#3daee9");

        save_accent_color(&dir, "#ff8800").unwrap();
        assert_eq!(load_accent_color(&dir), "#ff8800");

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_ui_font_through_toml_on_disk() {
        let dir = temp_dir("ui-font-roundtrip");

        assert_eq!(load_ui_font_family(&dir), None);
        assert_eq!(load_ui_font_point_size(&dir), None);

        save_ui_font_family(&dir, "Noto Sans").unwrap();
        save_ui_font_point_size(&dir, 12.0).unwrap();

        assert_eq!(load_ui_font_family(&dir), Some("Noto Sans".to_string()));
        assert_eq!(load_ui_font_point_size(&dir), Some(12.0));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_network_allowed_through_toml_on_disk() {
        let dir = temp_dir("network-allowed-roundtrip");

        assert!(!load_network_allowed(&dir));

        save_network_allowed(&dir, true).unwrap();
        assert!(load_network_allowed(&dir));

        save_network_allowed(&dir, false).unwrap();
        assert!(!load_network_allowed(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_layout_locked_through_toml_on_disk() {
        let dir = temp_dir("layout-locked-roundtrip");

        assert!(!load_layout_locked(&dir));

        save_layout_locked(&dir, true).unwrap();
        assert!(load_layout_locked(&dir));

        save_layout_locked(&dir, false).unwrap();
        assert!(!load_layout_locked(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_resize_locked_through_toml_on_disk() {
        let dir = temp_dir("resize-locked-roundtrip");

        assert!(!load_resize_locked(&dir));

        save_resize_locked(&dir, true).unwrap();
        assert!(load_resize_locked(&dir));

        save_resize_locked(&dir, false).unwrap();
        assert!(!load_resize_locked(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_bookmarks_through_toml_on_disk() {
        let dir = temp_dir("bookmarks-roundtrip");

        assert_eq!(load_bookmarks(&dir), Vec::new());

        let one = vec![BookmarkEntry {
            name: "Notes".to_string(),
            path: "/home/user/Notes".to_string(),
        }];
        save_bookmarks(&dir, &one).unwrap();
        assert_eq!(load_bookmarks(&dir), one);

        let two = vec![
            BookmarkEntry {
                name: "Notes".to_string(),
                path: "/home/user/Notes".to_string(),
            },
            BookmarkEntry {
                name: "Projects".to_string(),
                path: "/home/user/Projects".to_string(),
            },
        ];
        save_bookmarks(&dir, &two).unwrap();
        assert_eq!(load_bookmarks(&dir), two);

        save_bookmarks(&dir, &[]).unwrap();
        assert_eq!(load_bookmarks(&dir), Vec::new());

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_background_settings_through_toml_on_disk() {
        let dir = temp_dir("background-roundtrip");

        assert_eq!(load_background_image_path(&dir), None);
        assert_eq!(load_background_pane_opacity(&dir), 0.85);

        save_background_image_path(&dir, "/home/user/Pictures/wallpaper.png").unwrap();
        assert_eq!(
            load_background_image_path(&dir),
            Some("/home/user/Pictures/wallpaper.png".to_string())
        );

        save_background_pane_opacity(&dir, 0.5).unwrap();
        assert_eq!(load_background_pane_opacity(&dir), 0.5);

        save_background_pane_opacity(&dir, 5.0).unwrap();
        assert_eq!(load_background_pane_opacity(&dir), 1.0);

        clear_background_image_path(&dir).unwrap();
        assert_eq!(load_background_image_path(&dir), None);

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_background_effect_through_toml_on_disk() {
        let dir = temp_dir("background-effect-roundtrip");

        assert_eq!(load_background_effect(&dir), BackgroundEffect::default());

        let effect = BackgroundEffect {
            kind: "voronoi".to_string(),
            voronoi_cells: 200,
            ..BackgroundEffect::default()
        };
        save_background_effect(&dir, &effect).unwrap();
        assert_eq!(load_background_effect(&dir), effect);

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_explorer_alternating_row_colors_through_toml_on_disk() {
        let dir = temp_dir("explorer-alternating-row-colors-roundtrip");

        assert!(load_explorer_alternating_row_colors(&dir));

        save_explorer_alternating_row_colors(&dir, false).unwrap();
        assert!(!load_explorer_alternating_row_colors(&dir));

        save_explorer_alternating_row_colors(&dir, true).unwrap();
        assert!(load_explorer_alternating_row_colors(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_animation_settings_through_toml_on_disk() {
        let dir = temp_dir("animation-settings-roundtrip");

        assert_eq!(load_animation_speed(&dir), "normal");
        assert!(load_animations_enabled(&dir));

        save_animation_speed(&dir, "fast").unwrap();
        assert_eq!(load_animation_speed(&dir), "fast");

        save_animation_speed(&dir, "slow").unwrap();
        assert_eq!(load_animation_speed(&dir), "slow");

        save_animations_enabled(&dir, false).unwrap();
        assert!(!load_animations_enabled(&dir));

        save_animations_enabled(&dir, true).unwrap();
        assert!(load_animations_enabled(&dir));

        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn round_trips_ui_scale_through_toml_on_disk() {
        let dir = temp_dir("ui-scale-roundtrip");

        assert_eq!(load_ui_scale(&dir), 1.0);

        save_ui_scale(&dir, 1.25).unwrap();
        assert_eq!(load_ui_scale(&dir), 1.25);

        save_ui_scale(&dir, 0.75).unwrap();
        assert_eq!(load_ui_scale(&dir), 0.75);

        save_ui_scale(&dir, 10.0).unwrap();
        assert_eq!(load_ui_scale(&dir), 2.0);

        save_ui_scale(&dir, 0.0).unwrap();
        assert_eq!(load_ui_scale(&dir), 0.5);

        fs::remove_dir_all(&dir).unwrap();
    }
}
