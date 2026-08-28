//! Small wrapper around `notify` for watching a single directory
//! non-recursively. Mirrors the watcher setup in
//! cettila-view-qml-embed/src/cxxqt_object.rs (QmlFileSource), which is the
//! existing precedent in this codebase for filesystem-triggered hot reload.

use std::path::Path;
use std::sync::mpsc;
use std::time::Duration;

use notify::Watcher;

/// How long a burst of raw fs events must stay quiet before `on_change` is
/// actually called. Chosen to comfortably coalesce a single logical
/// operation (a git checkout, an archive extraction, an editor save) into
/// one call, without making a caller wait long enough to notice after a
/// single isolated change.
const DEBOUNCE: Duration = Duration::from_millis(250);

/// Watches `path` non-recursively and calls `on_change` for create/remove/
/// modify events. A burst of raw events (e.g. many files touched in one
/// operation) is coalesced into a single `on_change` call, fired once the
/// burst has been quiet for `DEBOUNCE` -- callers that redo a full
/// directory listing on every call would otherwise redo it once per raw
/// event instead of once per logical change. `on_change` runs on a
/// dedicated background thread (not `notify`'s own event thread), so
/// callers are expected to marshal back onto the Qt thread themselves (e.g.
/// via `CxxQtThread::queue`). Returns `None` if the watcher couldn't be
/// created or `path` couldn't be watched (e.g. it no longer exists).
pub fn watch_directory(
    path: &str,
    on_change: impl Fn() + Send + 'static,
) -> Option<notify::RecommendedWatcher> {
    let (tx, rx) = mpsc::channel::<()>();

    // Blocks on the first raw event of a burst, then drains (silently
    // coalescing) anything else that arrives within DEBOUNCE before firing
    // on_change once. Exits once `tx` is dropped -- which happens when the
    // notify watcher below (the sole owner of the closure that holds `tx`)
    // is dropped -- so this thread's lifetime is tied to the returned
    // watcher's without needing any explicit shutdown signal.
    std::thread::spawn(move || {
        while rx.recv().is_ok() {
            while rx.recv_timeout(DEBOUNCE).is_ok() {}
            on_change();
        }
    });

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
            let _ = tx.send(());
        }
    })
    .ok()?;

    watcher
        .watch(Path::new(path), notify::RecursiveMode::NonRecursive)
        .ok()?;
    Some(watcher)
}
