extern crate origami_gallery;

use cxx_qt_lib::QGuiApplication;
use std::ffi::CString;

unsafe extern "C" {
    fn createEngine() -> u64;
    fn loadQml(engine_ptr: u64, qml_url_utf8: *const std::os::raw::c_char) -> bool;
    fn rootWindowOf(engine_ptr: u64) -> u64;
    fn destroyEngine(engine_ptr: u64);
}

fn main() {
    cxx_qt::init_crate!(ayame);
    cxx_qt::init_crate!(origami);
    cxx_qt::init_crate!(origami_gallery);

    let _tracy_client = tracy_client::Client::start();

    let mut app = QGuiApplication::new();

    let qml_url = CString::new("qrc:/qt/qml/la/cettila/App/qml/main.qml")
        .expect("qml_url contains null byte");
    let engine_ptr = unsafe { createEngine() };
    let load_ok = unsafe { loadQml(engine_ptr, qml_url.as_ptr()) };
    if !load_ok {
        panic!("loadQml failed. Check stderr for QML load errors.");
    }

    let window_ptr = unsafe { rootWindowOf(engine_ptr) };
    if window_ptr == 0 {
        panic!("rootWindowOf: root object is not a QQuickWindow");
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }

    unsafe {
        destroyEngine(engine_ptr);
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn init_dependencies() {
        cxx_qt::init_crate!(origami_gallery);
    }
}
