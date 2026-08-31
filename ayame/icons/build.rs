// Qt-resource compilation is feature-gated (`qt-resource`, default-on) --
// see `Cargo.toml`'s feature doc comment. With the feature off, this
// build script is a no-op: no Qt tooling invoked, so a Qt-free consumer
// (`default-features = false`) can depend on this crate without needing
// Qt at build time at all.

// Shared with src/mapping.rs (which this crate's library exposes as
// `ayame_icons::MAPPING`) -- included directly here because a build
// script cannot depend on its own crate's library. Harmless to include
// unconditionally (plain data, no Qt tooling involved) even though only
// the `qt-resource` build below actually uses it.
include!("src/mapping.rs");

#[cfg(feature = "qt-resource")]
fn main() {
    use cxx_qt_build::{CxxQtBuilder, QmlModule};
    use qt_build_utils::{QResource, QResourceFile, QResources};
    use std::path::Path;

    println!("cargo:rerun-if-changed=vendor/tabler-icons/outline");

    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    let tabler_dir = Path::new(&manifest_dir).join("vendor/tabler-icons/outline");

    let icons = QResource::new()
        .prefix("/cettila/icons")
        .files(MAPPING.iter().map(|(freedesktop_name, tabler_name)| {
            QResourceFile::new(tabler_dir.join(format!("{tabler_name}.svg")))
                .alias(format!("{freedesktop_name}.svg"))
        }));

    CxxQtBuilder::new_qml_module(QmlModule::new("ayame_icons"))
        .qrc_resources(QResources::new().resource(icons))
        .build()
        .export();
}

#[cfg(not(feature = "qt-resource"))]
fn main() {}
