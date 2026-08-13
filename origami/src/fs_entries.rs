//! Shared directory-scanning logic. Originally cettila-view-explorer-only
//! (its tree/grid views), moved here so `image_picker_model`'s
//! `ImagePickerModel` can reuse it too -- `origami` is a dependency of
//! `explorer`, not the other way around, so this is the only shared
//! location both can reach without a circular dependency.

use std::path::Path;

/// Defaults to the dev vault (sandbox/). There is no config system yet, so this
/// is hardcoded the same way QmlView's `source` default points into sandbox/.
pub const DEFAULT_ROOT: &str = "/home/tefla/projects/develop/cettila-projects/cettila/sandbox";

pub struct DirEntryInfo {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub icon_name: &'static str,
    /// Whether this entry is itself a symlink (its *own* file type, not the
    /// target's -- a symlink pointing at a directory still has this true).
    pub is_symlink: bool,
    /// True for a symlink whose target can't be resolved (dangling, or a
    /// permission/loop error following it). Always false for non-symlinks.
    pub is_broken_symlink: bool,
}

/// Returns the entries directly under `path`, dotfiles excluded, sorted
/// directories-first then by name. Returns an empty Vec (never panics) for a
/// directory that can't be read (e.g. permission denied).
pub fn list_dir(path: &str) -> Vec<DirEntryInfo> {
    let Ok(read_dir) = std::fs::read_dir(path) else {
        return Vec::new();
    };

    let mut entries: Vec<DirEntryInfo> = read_dir
        .filter_map(|entry| entry.ok())
        .filter(|entry| !entry.file_name().to_string_lossy().starts_with('.'))
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            let file_type = entry.file_type().ok()?;
            let is_symlink = file_type.is_symlink();
            let entry_path = entry.path();
            // A symlink's own file_type() never reports is_dir() (it's the
            // link's type, not the target's), so navigability/icon must
            // come from following it explicitly via metadata() (unlike
            // symlink_metadata(), this follows the link). A dangling target
            // (or e.g. a permission error/symlink loop) is treated as a
            // broken link rather than a plain file.
            let (is_dir, is_broken_symlink) = if is_symlink {
                match std::fs::metadata(&entry_path) {
                    Ok(target_meta) => (target_meta.is_dir(), false),
                    Err(_) => (false, true),
                }
            } else {
                (file_type.is_dir(), false)
            };
            let path = entry_path.to_string_lossy().into_owned();
            let icon_name = icon_name(is_dir, &name);
            Some(DirEntryInfo {
                name,
                path,
                is_dir,
                icon_name,
                is_symlink,
                is_broken_symlink,
            })
        })
        .collect();

    entries.sort_by(|a, b| {
        (!a.is_dir, a.name.to_lowercase()).cmp(&(!b.is_dir, b.name.to_lowercase()))
    });
    entries
}

/// Like `list_dir`, but drops any non-directory entry whose extension
/// isn't in `extensions` when `Some` (directories always pass through
/// regardless, so hierarchy navigation still works) -- `None` means
/// unfiltered, identical to plain `list_dir`. Used by
/// cettila-view-explorer's `ExplorerGridModel`/`ExplorerTreeModel`, which
/// are configurable (via their `configure()` qinvokable) to act as either
/// the plain, unfiltered Explorer pane or a filtered file picker.
pub fn list_dir_filtered(path: &str, extensions: Option<&[String]>) -> Vec<DirEntryInfo> {
    let entries = list_dir(path);
    let Some(extensions) = extensions else {
        return entries;
    };
    entries
        .into_iter()
        .filter(|entry| entry.is_dir || matches_extension(&entry.name, extensions))
        .collect()
}

fn matches_extension(name: &str, extensions: &[String]) -> bool {
    let extension = name.rsplit('.').next().unwrap_or("").to_lowercase();
    extensions.iter().any(|candidate| *candidate == extension)
}

/// Parses a comma-separated extension list (e.g. `"png,jpg,jpeg"`) into
/// the `Some(Vec<String>)` shape `list_dir_filtered` expects -- an empty
/// (or all-whitespace) string means "no filter" (`None`), matching
/// Explorer's own default unfiltered behavior when nothing is configured.
/// Each entry is trimmed and lowercased so callers don't need to normalize
/// case themselves.
pub fn parse_extension_filter(raw: &str) -> Option<Vec<String>> {
    let extensions: Vec<String> = raw
        .split(',')
        .map(|part| part.trim().to_lowercase())
        .filter(|part| !part.is_empty())
        .collect();
    if extensions.is_empty() {
        None
    } else {
        Some(extensions)
    }
}

/// Moves every entry in `paths` into `target_dir` via a plain rename,
/// returning how many actually moved. Used by cettila-view-explorer's
/// drag-and-drop (both internal drag-move and, incidentally, any drop
/// whose dragged paths happen to already be inside `root_boundary` -- see
/// the calling qinvokable's own doc comment for why this boundary check is
/// the actual safety net, not anything on the QML/mime-data side).
/// `root_boundary` is the caller's own configured boundary -- `None` means
/// unrestricted (the plain Explorer pane's own default: it has no vault
/// sandbox of its own to enforce here), `Some(root)` is whatever a
/// file-picker instance configured via `configure()` was narrowed to, if
/// anything.
///
/// Silently skips (does not error) any path that:
/// - isn't inside `root_boundary`, when one is set (defends against an
///   incidental external drag-in being treated as a move of a file that
///   was never inside the caller's own configured boundary to begin with)
/// - is already directly inside `target_dir` (no-op move)
/// - is `target_dir` itself, or an ancestor of it (moving a directory
///   into its own descendant)
/// - fails for any other reason (permission, cross-filesystem rename,
///   name collision at the destination, ...) -- best-effort only in this
///   first pass, no error reporting back to the caller yet.
pub fn move_entries_to(paths: &[String], target_dir: &str, root_boundary: Option<&str>) -> usize {
    let mut moved = 0;

    for path in paths {
        if let Some(root) = root_boundary {
            if path != root && !path.starts_with(&format!("{root}/")) {
                continue;
            }
        }
        let source = Path::new(path);
        let Some(parent) = source.parent() else {
            continue;
        };
        if parent.to_string_lossy() == target_dir {
            continue;
        }
        if path == target_dir || format!("{target_dir}/").starts_with(&format!("{path}/")) {
            continue;
        }
        let Some(name) = source.file_name() else {
            continue;
        };
        let destination = Path::new(target_dir).join(name);
        if destination.exists() {
            continue;
        }
        if std::fs::rename(source, &destination).is_ok() {
            moved += 1;
        }
    }

    moved
}

/// Returns whether `path` is `root_boundary` itself or somewhere below it
/// -- same boundary check `move_entries_to` inlines for each source path,
/// factored out here since `copy_entries_to`/`link_entries_to` only ever
/// need to apply it to `target_dir`. Always true when `root_boundary` is
/// `None` (unrestricted).
fn is_within(path: &str, root_boundary: Option<&str>) -> bool {
    match root_boundary {
        Some(root) => path == root || path.starts_with(&format!("{root}/")),
        None => true,
    }
}

/// `target_dir/name`, or `target_dir/name (2)`, `target_dir/name (3)`, ...
/// if that already exists -- unlike `move_entries_to`'s plain skip-on-
/// collision, `copy_entries_to`/`link_entries_to` must handle "copy this
/// right back into the folder it came from" (a legitimate duplicate-in-
/// place action), which always collides with the original by name.
fn unique_destination(target_dir: &str, name: &std::ffi::OsStr) -> std::path::PathBuf {
    let target_dir = Path::new(target_dir);
    let first = target_dir.join(name);
    if !first.exists() {
        return first;
    }
    let name = name.to_string_lossy();
    let (stem, ext) = match name.rsplit_once('.') {
        Some((stem, ext)) if !stem.is_empty() => (stem, Some(ext)),
        _ => (name.as_ref(), None),
    };
    for n in 2.. {
        let candidate_name = match ext {
            Some(ext) => format!("{stem} ({n}).{ext}"),
            None => format!("{stem} ({n})"),
        };
        let candidate = target_dir.join(candidate_name);
        if !candidate.exists() {
            return candidate;
        }
    }
    unreachable!()
}

fn copy_recursive(source: &Path, destination: &Path) -> std::io::Result<()> {
    if source.is_dir() {
        std::fs::create_dir(destination)?;
        for entry in std::fs::read_dir(source)? {
            let entry = entry?;
            copy_recursive(&entry.path(), &destination.join(entry.file_name()))?;
        }
        Ok(())
    } else {
        std::fs::copy(source, destination).map(|_| ())
    }
}

/// Copies every entry in `paths` into `target_dir` (recursively, for
/// directories), returning how many actually copied. Unlike
/// `move_entries_to`, `paths` themselves are **not** bounded to
/// `root_boundary` -- only `target_dir` is (drop targets are always a row
/// from this instance's own listing, already guaranteed inside its
/// boundary, but checked here too as defense-in-depth) -- so this is what
/// makes dragging a file in from outside the app (an OS file manager)
/// actually work: the source can be anywhere the user has read access to.
/// A name collision at the destination is resolved via
/// `unique_destination` rather than skipped, since duplicating an entry
/// back into the folder it came from is a legitimate use (unlike a move,
/// which has no sensible "duplicate" reading). Still skips a source that
/// doesn't exist, or copying a directory into itself/its own descendant.
pub fn copy_entries_to(paths: &[String], target_dir: &str, root_boundary: Option<&str>) -> usize {
    if !is_within(target_dir, root_boundary) {
        return 0;
    }
    let mut copied = 0;
    for path in paths {
        let source = Path::new(path);
        if !source.exists() {
            continue;
        }
        if path == target_dir || format!("{target_dir}/").starts_with(&format!("{path}/")) {
            continue;
        }
        let Some(name) = source.file_name() else {
            continue;
        };
        let destination = unique_destination(target_dir, name);
        if copy_recursive(source, &destination).is_ok() {
            copied += 1;
        }
    }
    copied
}

/// Creates a symlink inside `target_dir` for every entry in `paths`,
/// pointing at that entry's own path, returning how many actually linked.
/// Same source-unrestricted/target-bounded/unique-name-on-collision shape
/// as `copy_entries_to` -- see its own doc comment.
pub fn link_entries_to(paths: &[String], target_dir: &str, root_boundary: Option<&str>) -> usize {
    if !is_within(target_dir, root_boundary) {
        return 0;
    }
    let mut linked = 0;
    for path in paths {
        let source = Path::new(path);
        if !source.exists() {
            continue;
        }
        let Some(name) = source.file_name() else {
            continue;
        };
        let destination = unique_destination(target_dir, name);
        if std::os::unix::fs::symlink(source, &destination).is_ok() {
            linked += 1;
        }
    }
    linked
}

fn icon_name(is_dir: bool, name: &str) -> &'static str {
    if is_dir {
        return "folder";
    }

    let extension = name.rsplit('.').next().unwrap_or("").to_lowercase();
    match extension.as_str() {
        "md" | "markdown" => "text-markdown",
        "png" | "jpg" | "jpeg" | "gif" | "svg" | "webp" => "image-x-generic",
        "mp4" | "m4v" | "mov" | "mkv" | "webm" | "avi" | "wmv" | "mpg" | "mpeg" | "ogv" => {
            "video-x-generic"
        }
        "pdf" => "application-pdf",
        _ => "text-x-generic",
    }
}
