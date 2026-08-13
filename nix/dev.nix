{
  lib,
  pkgs,
  inputs,
  stdenv,
  mkShell,
  qt6,
  ayame,
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
  #[ https://github.com/NixOS/nixpkgs/blob/master/pkgs/kde/plasma/breeze/default.nix ]
  buildInputs = with pkgs; [
    ayame

    #[ Rust ]
    rustToolchain
    cargo-edit
    cargo-outdated
    cargo-nextest

    #[ CMake ]
    cmake
    ninja

    #[ Qt ]
    qt6.qtbase
    qt6.qtsvg
    qt6.qtdeclarative
    #[ KDE ]
    kdePackages.extra-cmake-modules
    kdePackages.kcmutils
    kdePackages.kcoreaddons
    kdePackages.kcolorscheme
    kdePackages.kconfig
    kdePackages.kguiaddons
    kdePackages.ki18n
    kdePackages.kiconthemes
    kdePackages.kwindowsystem
    kdePackages.kdecoration
    #[ Graphics ]
    libGL
    mesa
  ];

  PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  LD_LIBRARY_PATH = lib.makeLibraryPath [
    ayame

    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtwebengine
    qt6.qtmultimedia

    pkgs.wayland
    pkgs.libxkbcommon
    pkgs.pipewire
    pkgs.mesa
    pkgs.libGL

    pkgs.stdenv.cc.cc.lib
  ];

  RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
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

    ayame
  ];
  QML2_IMPORT_PATH = QML_IMPORT_PATH;

  shellHook = ''
    export QT_QUICK_CONTROLS_STYLE="Ayame"
    export QMAKE="${qtToolchain.qmakeWrapper}/bin/qmake-wrapper"

    echo "🧪 C++ Qt Rust"
  '';
}
