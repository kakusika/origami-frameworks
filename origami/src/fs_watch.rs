//! Small wrapper around `notify` for watching a single directory
//! non-recursively. Mirrors the watcher setup in
//! cettila-view-qml-embed/src/cxxqt_object.rs (QmlFileSource), which is the
//! existing precedent in this codebase for filesystem-triggered hot reload.

use std::path::Path;

use notify::Watcher;

/// Watches `path` non-recursively and calls `on_change` for create/remove/
/// modify events. `on_change` runs on the watcher's background thread, so
/// callers are expected to marshal back onto the Qt thread themselves (e.g.
/// via `CxxQtThread::queue`). Returns `None` if the watcher couldn't be
/// created or `path` couldn't be watched (e.g. it no longer exists).
pub fn watch_directory(
    path: &str,
    on_change: impl Fn() + Send + 'static,
) -> Option<notify::RecommendedWatcher> {
    let mut watcher = notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
        let Ok(event) = event else {
            return;
        };
        if matches!(
            event.kind,
            notify::EventKind::Create(_)
                | notify::EventKind::Remove(_)
                | notify::EventKind::Modify(_)
        ) {
            on_change();
        }
    })
    .ok()?;

    watcher
        .watch(Path::new(path), notify::RecursiveMode::NonRecursive)
        .ok()?;
    Some(watcher)
}
