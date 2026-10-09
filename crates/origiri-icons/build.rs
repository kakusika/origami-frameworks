use std::env;
use std::fs;
use std::io::Write;
use std::path::Path;

use flate2::Compression;
use flate2::write::GzEncoder;

/// Generates the Rust-side dynamic icon lookup (`icon_lookup.rs`, included
/// by `src/lib.rs`): for each `ui/icons/<set>/*.svg`, gzip-compresses the
/// bytes into `OUT_DIR` and emits one `include_bytes!` match arm. This is
/// the Rust equivalent of `scripts/gen-icons-slint.js`, for callers that
/// need to go from a *runtime* string (e.g. a tomet document's
/// `@doc.icon(name, pkg)`) to an icon -- `@image-url()` only ever resolves
/// a fixed literal per call site, which the generated `ui/icons/<set>.slint`
/// globals exist for instead (see `ui/icons.slint`'s doc comment).
///
/// Compressed, not raw: Slint tree-shakes a global's unreferenced
/// properties (confirmed against a real build: a consumer's compiled
/// binary didn't grow when this crate's own `TablerIcons` global went from
/// ~30 properties to all 5000+ vendored icons), but a match on a runtime
/// string can't be tree-shaken the same way -- every arm's bytes compile
/// in regardless of whether a given caller ever requests that icon. All of
/// `ui/icons/tabler/` is 21 MB raw; gzipped per-file (so one icon can be
/// decompressed without touching the rest), 1.78 MB -- worth doing, not
/// worth skipping over.
fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    println!("cargo:UI_DIR={manifest_dir}/ui");
    println!("cargo:rerun-if-changed=ui");

    let icons_dir = Path::new(&manifest_dir).join("ui").join("icons");
    let out_dir = env::var("OUT_DIR").unwrap();
    let gz_dir = Path::new(&out_dir).join("icons_gz");

    let mut set_entries: Vec<_> = fs::read_dir(&icons_dir)
        .expect("ui/icons exists")
        .filter_map(|e| e.ok())
        .filter(|e| e.path().is_dir())
        .collect();
    set_entries.sort_by_key(|e| e.file_name());

    let mut generated = String::new();
    let mut set_fns = Vec::new();

    for set_entry in set_entries {
        let set = set_entry.file_name().to_string_lossy().into_owned();
        let set_dir = set_entry.path();
        let set_gz_dir = gz_dir.join(&set);
        fs::create_dir_all(&set_gz_dir).expect("create OUT_DIR icon set dir");

        let mut slugs: Vec<String> = fs::read_dir(&set_dir)
            .unwrap_or_else(|e| panic!("read {}: {e}", set_dir.display()))
            .filter_map(|e| e.ok())
            .filter_map(|e| {
                e.file_name()
                    .to_string_lossy()
                    .strip_suffix(".svg")
                    .map(str::to_owned)
            })
            .collect();
        slugs.sort();

        let fn_name = format!("{set}_icon_svg_gz");
        generated.push_str(&format!(
            "fn {fn_name}(slug: &str) -> Option<&'static [u8]> {{\n    match slug {{\n"
        ));
        for slug in &slugs {
            let svg_path = set_dir.join(format!("{slug}.svg"));
            let raw =
                fs::read(&svg_path).unwrap_or_else(|e| panic!("read {}: {e}", svg_path.display()));
            let mut encoder = GzEncoder::new(Vec::new(), Compression::best());
            encoder.write_all(&raw).expect("gzip icon svg");
            let compressed = encoder.finish().expect("finish gzip stream");

            let gz_path = set_gz_dir.join(format!("{slug}.svg.gz"));
            fs::write(&gz_path, &compressed)
                .unwrap_or_else(|e| panic!("write {}: {e}", gz_path.display()));

            generated.push_str(&format!(
                "        {slug:?} => Some(include_bytes!({gz_path:?}) as &[u8]),\n"
            ));
        }
        generated.push_str("        _ => None,\n    }\n}\n\n");

        let names_fn = format!("{set}_icon_names");
        generated.push_str(&format!(
            "fn {names_fn}() -> &'static [&'static str] {{\n    &[\n"
        ));
        for slug in &slugs {
            generated.push_str(&format!("        {slug:?},\n"));
        }
        generated.push_str("    ]\n}\n\n");

        set_fns.push((set, fn_name, names_fn));
    }

    generated.push_str(
        "/// Gzip-compressed svg bytes for `pkg`'s `slug` icon, or `None` if either\n\
         /// isn't vendored. Private: callers go through `icon_svg` (`src/lib.rs`),\n\
         /// which decompresses this.\n\
         fn icon_svg_gz(pkg: &str, slug: &str) -> Option<&'static [u8]> {\n    match pkg {\n",
    );
    for (set, fn_name, _) in &set_fns {
        generated.push_str(&format!("        {set:?} => {fn_name}(slug),\n"));
    }
    generated.push_str("        _ => None,\n    }\n}\n\n");

    generated.push_str(
        "/// Every slug `pkg` vendors (e.g. for an icon picker), or `&[]` if `pkg`\n\
         /// isn't vendored at all. Private: callers go through `icon_names`\n\
         /// (`src/lib.rs`).\n\
         fn icon_names_for(pkg: &str) -> &'static [&'static str] {\n    match pkg {\n",
    );
    for (set, _, names_fn) in &set_fns {
        generated.push_str(&format!("        {set:?} => {names_fn}(),\n"));
    }
    generated.push_str("        _ => &[],\n    }\n}\n");

    let out_path = Path::new(&out_dir).join("icon_lookup.rs");
    fs::write(&out_path, generated).expect("write generated icon_lookup.rs");
}
