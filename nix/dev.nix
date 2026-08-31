{
  lib,
  pkgs,
  inputs,
  stdenv,
  mkShell,
  qt6,
  ...
}:
let
  qtToolchain = pkgs.callPackage ./qt-toolchain.nix { inherit qt6; };
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
    ##[ CMake ]
    cmake
    ninja
    stdenv.cc.cc.lib

    #[ Runtime ]
    ##[ Qt ]
    qt6.qtbase
    qt6.qtsvg
    qt6.qtdeclarative
    ##[ Breeze ]
    kdePackages.qqc2-breeze-style
    kdePackages.kirigami
    kdePackages.kguiaddons
    kdePackages.kirigami-gallery
    ##[ Wayland ]
    fontconfig
    freetype
    openssl
    glib
    vulkan-loader
    vulkan-validation-layers
    vulkan-tools
    vulkan-headers
    wayland
    libxkbcommon
    libinput
    ##[ Misc ]
    pipewire
    pkg-config
    ##[ Graphics ]
    libGL
    mesa
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
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtwayland
      qt6.qtwebengine
      qt6.qtmultimedia

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
  #[ Qt ]
  ENV_QT_INCLUDE_PATH = "${qt6.qtdeclarative}/include";
  QT_QPA_PLATFORM_PLUGIN_PATH = "${qt6.qtbase}/${qt6.qtbase.qtPluginPrefix}/platforms";
  QT_PLUGIN_PATH = lib.makeSearchPath "lib/qt-6/plugins" [
    qt6.qtbase
    qt6.qtwayland
    qt6.qtmultimedia
  ];
  QML_IMPORT_PATH = lib.makeSearchPath "lib/qt-6/qml" [
    qt6.qtdeclarative
    qt6.qtmultimedia
    qt6.qtwayland
    pkgs.kdePackages.qqc2-breeze-style
    pkgs.kdePackages.kirigami.unwrapped
    pkgs.kdePackages.kguiaddons
  ];
  QML2_IMPORT_PATH = QML_IMPORT_PATH;

  shellHook = ''
    export QT_QUICK_CONTROLS_STYLE="org.kde.breeze"
    export QT_LOGGING_RULES="qt.qpa.wayland.textinput=false"
    export QMAKE="${qtToolchain.qmakeWrapper}/bin/qmake-wrapper"

    echo "🧪 C++ Qt Rust"
  '';
}
