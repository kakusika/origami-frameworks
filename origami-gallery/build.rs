use cxx_qt_build::{CxxQtBuilder, QmlModule};
use std::path::Path;

fn main() {
    println!("cargo:rerun-if-changed=qml");
    println!("cargo:rerun-if-changed=cpp");
    println!("cargo:rerun-if-changed=src/cxxqt_object.rs");

    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    let cpp_dir = Path::new(&manifest_dir).join("cpp");

    let builder = CxxQtBuilder::new_qml_module(QmlModule::new("la.cettila.App").qml_files([
        "qml/main.qml",
        "qml/OrigamiWidgetsPage.qml",
        "qml/QQC2WidgetsPage.qml",
        "qml/AyameWidgetsPage.qml",
    ]))
    .files(["src/cxxqt_object.rs"])
    .qt_module("Quick")
    .qt_module("QuickControls2")
    .cpp_file(cpp_dir.join("app_bootstrap.h"))
    .cpp_file(cpp_dir.join("app_bootstrap.cpp"));

    let qml_debug_enabled = std::env::var_os("CARGO_FEATURE_QML_DEBUG").is_some();

    let builder = unsafe {
        builder.cc_builder(move |cc| {
            cc.define("_FORTIFY_SOURCE", Some("0"));
            if qml_debug_enabled {
                cc.define("QT_QML_DEBUG", None);
            }
        })
    };

    builder.build();
}
