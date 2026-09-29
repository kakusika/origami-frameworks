{
  lib,
  pkgs,
  inputs,
  stdenv,
  mkShell,
  ...
}:
let
  rustToolchain = inputs.fenix.packages.${stdenv.hostPlatform.system}.stable.withComponents [
    "cargo"
    "clippy"
    "rustc"
    "rust-src"
    # "rust-analyzer"
  ];
in
mkShell rec {
  buildInputs = with pkgs; [
    #[ Develop ]
    ##[ Rust ]
    rustToolchain
    cargo-edit
    cargo-outdated
    cargo-nextest
    stdenv.cc.cc.lib

    #[ Runtime ]
    ##[ Wayland & Input ]
    fontconfig
    freetype
    openssl
    glib
    wayland
    libxkbcommon
    libinput

    ##[ Vulkan & Graphics ]
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
    vulkan-headers
    libGL
    mesa

    ##[ Misc ]
    pipewire
    pkg-config
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
    echo "🦀 Origami Frameworks (Rust + Slint)"
  '';
}
