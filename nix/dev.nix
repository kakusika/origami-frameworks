{
  lib,
  pkgs,
  mkShell,
  fenix,
  tmtbook,
  tomet,
  tomet-lsp,
  twrit,
  ...
}:
let
  rustToolchain = fenix.combine [
    (fenix.stable.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rust-src"
      "rustfmt"
      "rust-analyzer"
    ])
  ];
in
mkShell rec {
  buildInputs = with pkgs; [
    #= Develop
    tomet
    tomet-lsp
    tmtbook
    twrit
    deno
    just
    #== Slint
    slint-lsp
    slint-viewer
    #== Build
    pkg-config
    #== Rust
    rustToolchain
    cargo-edit
    cargo-outdated
    cargo-nextest
    stdenv.cc.cc.lib

    #= Runtime
    #== Wayland
    fontconfig
    freetype
    openssl
    glib
    wayland
    libxkbcommon
    libinput
    pipewire

    #== Graphics
    libGL
    mesa
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
  ];

  PKG_CONFIG_PATH = lib.makeSearchPathOutput "dev" "lib/pkgconfig" [
    pkgs.openssl
    pkgs.fontconfig
    pkgs.freetype
    pkgs.wayland
    pkgs.libxkbcommon
  ];
  LD_LIBRARY_PATH =
    lib.makeLibraryPath [
      pkgs.wayland
      pkgs.libxkbcommon
      pkgs.pipewire
      pkgs.fontconfig
      pkgs.freetype
      pkgs.mesa
      pkgs.libGL
      pkgs.vulkan-loader
      pkgs.stdenv.cc.cc.lib
    ]
    + ":/run/opengl-driver/lib";

  RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
  VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

  shellHook = ''
    echo "🦀 Rust Slint Tomet"
  '';
}
