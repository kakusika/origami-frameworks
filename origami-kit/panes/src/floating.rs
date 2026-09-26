//! State of the app's floating (in-app, MDI-style) windows: which are open, in
//! what stacking order, where, and which one is active -- plus save/restore.
//! Ported from `origami/qml/floating/FloatingWindowRegistry.qml`; toolkit
//! independent like the rest of this crate. The window widget itself is
//! `origami-slint`'s `floating_window.slint`; this is only the bookkeeping.
//!
//! Stacking is the order of [`FloatingWindows::windows`]: last is frontmost.
//! (The QML original kept a `z` counter; a Slint host just iterates in order,
//! or reads [`FloatingWindow::z`].)

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// One open floating window. Field names and JSON keys match what Cettila's
/// `serializeWindows()` writes, so saved workspaces keep loading.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FloatingWindow {
    /// Assigned by the registry, never saved (ids are per session).
    #[serde(skip, default)]
    pub id: i32,
    /// Which view fills the window. Empty means "not restorable" (a plain
    /// hosted item), so it is skipped when saving.
    pub view_type: String,
    pub title: String,
    /// Whatever the view chose to persist (`paneSerialize()` in QML).
    #[serde(default)]
    pub props: Value,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    #[serde(default)]
    pub minimized: bool,
    #[serde(default)]
    pub maximized: bool,
    /// Stacking rank, larger is nearer the front. Not saved.
    #[serde(skip, default)]
    pub z: i32,
}

#[derive(Debug, Default, Clone)]
pub struct FloatingWindows {
    windows: Vec<FloatingWindow>,
    next_id: i32,
    next_z: i32,
    active: Option<i32>,
}

impl FloatingWindows {
    pub fn new() -> Self {
        Self { windows: Vec::new(), next_id: 1, next_z: 1, active: None }
    }

    /// Open windows, back to front.
    pub fn windows(&self) -> &[FloatingWindow] {
        &self.windows
    }

    /// The frontmost-focused window, `None` before any was focused or after it closed.
    pub fn active(&self) -> Option<i32> {
        self.active
    }

    pub fn get(&self, id: i32) -> Option<&FloatingWindow> {
        self.windows.iter().find(|w| w.id == id)
    }

    /// Opens a window in front and makes it active. Returns its id.
    /// (QML `registerWindow` / `open`.)
    pub fn open(&mut self, mut window: FloatingWindow) -> i32 {
        let id = self.next_id;
        self.next_id += 1;
        window.id = id;
        window.z = self.next_z;
        self.next_z += 1;
        self.windows.push(window);
        self.active = Some(id);
        id
    }

    /// Closes a window; `false` if there is no such id. (QML `close`/`unregisterWindow`.)
    pub fn close(&mut self, id: i32) -> bool {
        let before = self.windows.len();
        self.windows.retain(|w| w.id != id);
        if self.active == Some(id) {
            self.active = None;
        }
        self.windows.len() != before
    }

    /// Raises a window to the front and makes it active. (QML `bringToFront`.)
    pub fn bring_to_front(&mut self, id: i32) -> bool {
        let Some(pos) = self.windows.iter().position(|w| w.id == id) else {
            return false;
        };
        let mut window = self.windows.remove(pos);
        window.z = self.next_z;
        self.next_z += 1;
        self.windows.push(window);
        self.active = Some(id);
        true
    }

    /// Records where the widget moved/resized to. `false` if the id is unknown.
    pub fn set_geometry(&mut self, id: i32, x: f32, y: f32, width: f32, height: f32) -> bool {
        self.with(id, |w| (w.x, w.y, w.width, w.height) = (x, y, width, height))
    }

    pub fn set_state(&mut self, id: i32, minimized: bool, maximized: bool) -> bool {
        self.with(id, |w| (w.minimized, w.maximized) = (minimized, maximized))
    }

    fn with(&mut self, id: i32, f: impl FnOnce(&mut FloatingWindow)) -> bool {
        match self.windows.iter_mut().find(|w| w.id == id) {
            Some(w) => {
                f(w);
                true
            }
            None => false,
        }
    }

    /// The windows worth saving, back to front: those with a `view_type`.
    /// (QML `serializeWindows`.)
    pub fn serialize(&self) -> Value {
        let saved: Vec<&FloatingWindow> =
            self.windows.iter().filter(|w| !w.view_type.is_empty()).collect();
        serde_json::to_value(saved).unwrap_or(Value::Array(Vec::new()))
    }

    /// Reopens saved windows, keeping their order. An entry whose `view_type`
    /// `is_known` rejects is dropped, as is one that does not parse -- the same
    /// graceful degradation `PaneTree` gives an unknown view type. Returns how
    /// many were dropped so a caller can warn. (QML `restoreWindows`.)
    pub fn restore(&mut self, saved: &Value, is_known: impl Fn(&str) -> bool) -> usize {
        let Some(entries) = saved.as_array() else {
            return 0;
        };
        let mut dropped = 0;
        for entry in entries {
            match serde_json::from_value::<FloatingWindow>(entry.clone()) {
                Ok(window) if is_known(&window.view_type) => {
                    self.open(window);
                }
                _ => dropped += 1,
            }
        }
        dropped
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn win(view_type: &str, title: &str) -> FloatingWindow {
        FloatingWindow {
            id: 0,
            view_type: view_type.into(),
            title: title.into(),
            props: json!({}),
            x: 10.0,
            y: 20.0,
            width: 300.0,
            height: 200.0,
            minimized: false,
            maximized: false,
            z: 0,
        }
    }

    #[test]
    fn open_puts_the_window_in_front_and_active() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        let b = fw.open(win("preview", "b"));
        assert_ne!(a, b);
        assert_eq!(fw.active(), Some(b));
        let order: Vec<i32> = fw.windows().iter().map(|w| w.id).collect();
        assert_eq!(order, vec![a, b]);
        assert!(fw.get(b).unwrap().z > fw.get(a).unwrap().z);
    }

    #[test]
    fn bring_to_front_reorders_and_activates() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        let b = fw.open(win("preview", "b"));
        assert!(fw.bring_to_front(a));
        let order: Vec<i32> = fw.windows().iter().map(|w| w.id).collect();
        assert_eq!(order, vec![b, a]);
        assert_eq!(fw.active(), Some(a));
        assert!(fw.get(a).unwrap().z > fw.get(b).unwrap().z);
        assert!(!fw.bring_to_front(999));
    }

    #[test]
    fn closing_the_active_window_clears_active() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        let b = fw.open(win("preview", "b"));
        assert!(fw.close(b));
        assert_eq!(fw.active(), None);
        assert!(!fw.close(b));
        // Closing a background window leaves the active one alone.
        let c = fw.open(win("preview", "c"));
        assert!(fw.close(a));
        assert_eq!(fw.active(), Some(c));
    }

    #[test]
    fn ids_are_not_reused() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        fw.close(a);
        assert_ne!(fw.open(win("preview", "b")), a);
    }

    #[test]
    fn geometry_and_state_updates() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        assert!(fw.set_geometry(a, 1.0, 2.0, 3.0, 4.0));
        assert!(fw.set_state(a, true, false));
        let w = fw.get(a).unwrap();
        assert_eq!((w.x, w.y, w.width, w.height, w.minimized), (1.0, 2.0, 3.0, 4.0, true));
        assert!(!fw.set_geometry(999, 0.0, 0.0, 0.0, 0.0));
    }

    #[test]
    fn serialize_uses_cettilas_keys_and_skips_windows_without_a_view_type() {
        let mut fw = FloatingWindows::new();
        let mut a = win("preview", "a.png");
        a.props = json!({"path": "/v/a.png"});
        fw.open(a);
        fw.open(win("", "hosted item"));
        let saved = fw.serialize();
        assert_eq!(
            saved,
            json!([{
                "viewType": "preview",
                "title": "a.png",
                "props": {"path": "/v/a.png"},
                "x": 10.0, "y": 20.0, "width": 300.0, "height": 200.0,
                "minimized": false, "maximized": false
            }])
        );
    }

    #[test]
    fn restore_reads_what_cettila_wrote_and_drops_unknown_view_types() {
        // Shape written by the QML `serializeWindows()`.
        let saved = json!([
            {"viewType": "preview", "title": "a", "props": {"path": "/v/a"},
             "x": 5, "y": 6, "width": 300, "height": 200, "minimized": true, "maximized": false},
            {"viewType": "gone", "title": "b", "props": {}, "x": 0, "y": 0, "width": 1, "height": 1,
             "minimized": false, "maximized": false},
            {"nonsense": true}
        ]);
        let mut fw = FloatingWindows::new();
        let dropped = fw.restore(&saved, |t| t == "preview");
        assert_eq!(dropped, 2);
        assert_eq!(fw.windows().len(), 1);
        let w = &fw.windows()[0];
        assert_eq!((w.view_type.as_str(), w.x, w.minimized), ("preview", 5.0, true));
        assert_eq!(w.props, json!({"path": "/v/a"}));
    }

    #[test]
    fn restore_of_a_non_array_is_a_no_op() {
        let mut fw = FloatingWindows::new();
        assert_eq!(fw.restore(&json!({}), |_| true), 0);
        assert!(fw.windows().is_empty());
    }

    #[test]
    fn serialize_then_restore_round_trips() {
        let mut fw = FloatingWindows::new();
        let a = fw.open(win("preview", "a"));
        fw.open(win("preview", "b"));
        fw.set_geometry(a, 50.0, 60.0, 400.0, 300.0);
        let saved = fw.serialize();
        let mut again = FloatingWindows::new();
        assert_eq!(again.restore(&saved, |_| true), 0);
        assert_eq!(again.windows().len(), 2);
        let (x, y) = (again.windows()[0].x, again.windows()[0].y);
        assert_eq!((x, y), (50.0, 60.0));
    }
}
