use std::path::Path;
use std::pin::Pin;

use crate::pane_tree::PaneTree;
use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;

fn vault_root() -> &'static Path {
    Path::new(origami_config::workspace::DEFAULT_VAULT_ROOT)
}

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!(<QtQml/qqmlregistration.h>);
    }

    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type WorkspaceStore = super::WorkspaceStoreRust;

        #[qinvokable]
        fn load_json(self: Pin<&mut WorkspaceStore>) -> QString;

        #[qinvokable]
        fn save_json(self: Pin<&mut WorkspaceStore>, json: &QString);
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, tree_json)]
        type WorkspaceManager = super::WorkspaceManagerRust;

        #[qinvokable]
        fn load_tree(self: Pin<&mut WorkspaceManager>);

        #[qinvokable]
        fn save_tree(self: Pin<&mut WorkspaceManager>);

        #[qinvokable]
        fn load_workspace(self: Pin<&mut WorkspaceManager>);

        #[qinvokable]
        fn save_workspace(self: Pin<&mut WorkspaceManager>);

        #[qinvokable]
        fn update_tree_json(self: Pin<&mut WorkspaceManager>, json: &QString) -> bool;

        #[qinvokable]
        fn add_tab(
            self: Pin<&mut WorkspaceManager>,
            group_id: i32,
            view_type: &QString,
            title: &QString,
        ) -> i32;

        #[qinvokable]
        fn close_tab(self: Pin<&mut WorkspaceManager>, group_id: i32, tab_id: i32) -> bool;

        #[qinvokable]
        fn set_current_tab(self: Pin<&mut WorkspaceManager>, group_id: i32, index: i32) -> bool;

        #[qinvokable]
        fn change_pane_type(
            self: Pin<&mut WorkspaceManager>,
            pane_id: i32,
            new_type: &QString,
            new_title: &QString,
        ) -> bool;

        #[qinvokable]
        fn split_pane(
            self: Pin<&mut WorkspaceManager>,
            target_id: i32,
            orientation: &QString,
            new_view_type: &QString,
            new_title: &QString,
        ) -> i32;

        #[qinvokable]
        fn move_tab(
            self: Pin<&mut WorkspaceManager>,
            from_group_id: i32,
            from_index: i32,
            to_group_id: i32,
            to_index: i32,
        ) -> bool;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type LayoutLockSettings = super::LayoutLockSettingsRust;

        #[qinvokable]
        fn layout_locked(self: Pin<&mut LayoutLockSettings>) -> bool;

        #[qinvokable]
        fn set_layout_locked(self: Pin<&mut LayoutLockSettings>, locked: bool);
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        type ResizeLockSettings = super::ResizeLockSettingsRust;

        #[qinvokable]
        fn resize_locked(self: Pin<&mut ResizeLockSettings>) -> bool;

        #[qinvokable]
        fn set_resize_locked(self: Pin<&mut ResizeLockSettings>, locked: bool);
    }

    unsafe extern "RustQt" {
        // Read-only mirror of the persisted background-image pick, for
        // PaneBackdrop.qml to seed itself from at construction. Writing
        // (picking an image, tuning an effect) is the consuming app's job;
        // see PaneBackdrop.qml's own comment for why this crate only reads.
        #[qobject]
        #[qml_element]
        type BackgroundState = super::BackgroundStateRust;

        #[qinvokable]
        fn image_path(self: Pin<&mut BackgroundState>) -> QString;

        #[qinvokable]
        fn pane_opacity(self: Pin<&mut BackgroundState>) -> f64;
    }
}

#[derive(Default)]
pub struct WorkspaceStoreRust;

impl ffi::WorkspaceStore {
    fn load_json(self: Pin<&mut Self>) -> QString {
        match origami_config::workspace::load_workspace_json(vault_root()) {
            Some(json) => QString::from(json.as_str()),
            None => QString::from(""),
        }
    }

    fn save_json(self: Pin<&mut Self>, json: &QString) {
        if let Err(err) =
            origami_config::workspace::save_workspace_json(vault_root(), &json.to_string())
        {
            eprintln!("origami: failed to save workspace: {err}");
        }
    }
}

pub struct WorkspaceManagerRust {
    tree: PaneTree,
    tree_json: QString,
}

impl Default for WorkspaceManagerRust {
    fn default() -> Self {
        Self {
            tree: PaneTree::new(None),
            tree_json: QString::from(""),
        }
    }
}

impl ffi::WorkspaceManager {
    fn load_tree(self: Pin<&mut Self>) {
        self.load_workspace();
    }

    fn save_tree(self: Pin<&mut Self>) {
        self.save_workspace();
    }

    fn load_workspace(mut self: Pin<&mut Self>) {
        if let Some(json_str) = origami_config::workspace::load_workspace_json(vault_root()) {
            if let Ok(tree) = PaneTree::from_json(&json_str) {
                let qjson = QString::from(json_str.as_str());
                self.as_mut().rust_mut().tree = tree;
                self.as_mut().set_tree_json(qjson);
            }
        }
    }

    fn save_workspace(self: Pin<&mut Self>) {
        let json_str = self.rust().tree_json.to_string();
        if !json_str.is_empty() {
            if let Err(err) =
                origami_config::workspace::save_workspace_json(vault_root(), &json_str)
            {
                eprintln!("origami: failed to save workspace tree: {err}");
            }
        }
    }

    fn update_tree_json(mut self: Pin<&mut Self>, json: &QString) -> bool {
        let json_str = json.to_string();
        match PaneTree::from_json(&json_str) {
            Ok(tree) => {
                self.as_mut().rust_mut().tree = tree;
                self.as_mut().set_tree_json(json.clone());
                true
            }
            Err(err) => {
                eprintln!("origami: invalid workspace tree json: {err}");
                false
            }
        }
    }

    fn add_tab(
        mut self: Pin<&mut Self>,
        group_id: i32,
        view_type: &QString,
        title: &QString,
    ) -> i32 {
        let vtype = view_type.to_string();
        let t = title.to_string();
        if let Some(new_id) = self.as_mut().rust_mut().tree.add_tab(group_id, &vtype, &t) {
            if let Ok(updated_json) = self.rust().tree.serialize_json() {
                let qjson = QString::from(updated_json.as_str());
                self.as_mut().set_tree_json(qjson);
                return new_id;
            }
        }
        -1
    }

    fn close_tab(mut self: Pin<&mut Self>, group_id: i32, tab_id: i32) -> bool {
        if self.as_mut().rust_mut().tree.close_tab(group_id, tab_id) {
            if let Ok(updated_json) = self.rust().tree.serialize_json() {
                let qjson = QString::from(updated_json.as_str());
                self.as_mut().set_tree_json(qjson);
                return true;
            }
        }
        false
    }

    fn set_current_tab(mut self: Pin<&mut Self>, group_id: i32, index: i32) -> bool {
        if index >= 0 {
            if self
                .as_mut()
                .rust_mut()
                .tree
                .set_current_tab(group_id, index as usize)
            {
                if let Ok(updated_json) = self.rust().tree.serialize_json() {
                    let qjson = QString::from(updated_json.as_str());
                    self.as_mut().set_tree_json(qjson);
                    return true;
                }
            }
        }
        false
    }

    fn change_pane_type(
        mut self: Pin<&mut Self>,
        pane_id: i32,
        new_type: &QString,
        new_title: &QString,
    ) -> bool {
        let vtype = new_type.to_string();
        let t = new_title.to_string();
        if self
            .as_mut()
            .rust_mut()
            .tree
            .change_pane_type(pane_id, &vtype, &t)
        {
            if let Ok(updated_json) = self.rust().tree.serialize_json() {
                let qjson = QString::from(updated_json.as_str());
                self.as_mut().set_tree_json(qjson);
                return true;
            }
        }
        false
    }

    fn split_pane(
        mut self: Pin<&mut Self>,
        target_id: i32,
        orientation: &QString,
        new_view_type: &QString,
        new_title: &QString,
    ) -> i32 {
        let orient = orientation.to_string();
        let vtype = new_view_type.to_string();
        let t = new_title.to_string();
        if let Some(new_id) = self
            .as_mut()
            .rust_mut()
            .tree
            .split_pane(target_id, &orient, &vtype, &t)
        {
            if let Ok(updated_json) = self.rust().tree.serialize_json() {
                let qjson = QString::from(updated_json.as_str());
                self.as_mut().set_tree_json(qjson);
                return new_id;
            }
        }
        -1
    }

    fn move_tab(
        mut self: Pin<&mut Self>,
        from_group_id: i32,
        from_index: i32,
        to_group_id: i32,
        to_index: i32,
    ) -> bool {
        if from_index >= 0 && to_index >= 0 {
            if self.as_mut().rust_mut().tree.move_tab(
                from_group_id,
                from_index as usize,
                to_group_id,
                to_index as usize,
            ) {
                if let Ok(updated_json) = self.rust().tree.serialize_json() {
                    let qjson = QString::from(updated_json.as_str());
                    self.as_mut().set_tree_json(qjson);
                    return true;
                }
            }
        }
        false
    }
}

#[derive(Default)]
pub struct LayoutLockSettingsRust;

impl ffi::LayoutLockSettings {
    fn layout_locked(self: Pin<&mut Self>) -> bool {
        origami_config::settings::load_layout_locked(vault_root())
    }

    fn set_layout_locked(self: Pin<&mut Self>, locked: bool) {
        if let Err(err) = origami_config::settings::save_layout_locked(vault_root(), locked) {
            eprintln!("origami: failed to save layout lock setting: {err}");
        }
    }
}

#[derive(Default)]
pub struct ResizeLockSettingsRust;

impl ffi::ResizeLockSettings {
    fn resize_locked(self: Pin<&mut Self>) -> bool {
        origami_config::settings::load_resize_locked(vault_root())
    }

    fn set_resize_locked(self: Pin<&mut Self>, locked: bool) {
        if let Err(err) = origami_config::settings::save_resize_locked(vault_root(), locked) {
            eprintln!("origami: failed to save resize lock setting: {err}");
        }
    }
}

#[derive(Default)]
pub struct BackgroundStateRust;

impl ffi::BackgroundState {
    fn image_path(self: Pin<&mut Self>) -> QString {
        match origami_config::settings::load_background_image_path(vault_root()) {
            Some(path) => QString::from(path.as_str()),
            None => QString::from(""),
        }
    }

    fn pane_opacity(self: Pin<&mut Self>) -> f64 {
        origami_config::settings::load_background_pane_opacity(vault_root())
    }
}
