use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    println!("cargo:rerun-if-changed=qml");

    // Pure-QML module, no Rust bridge objects of its own -- see
    // ayame-stylekit's own build.rs (ayame/crates/stylekit/build.rs) for
    // the identical shape/reasoning: one QmlModule per crate, no
    // `.export()` (which needs a `links` manifest key this crate has no
    // downstream C++/CMake consumer to justify declaring).
    CxxQtBuilder::new_qml_module(QmlModule::new("la.cettila.SettingsKit").qml_files(["qml/CategorySidebar.qml"]))
        .qt_module("Quick")
        .build();
}
