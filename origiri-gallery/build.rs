fn main() {
    let config = origiri_build::configure(slint_build::CompilerConfiguration::new());
    slint_build::compile_with_config("ui/app.slint", config).unwrap();
}
