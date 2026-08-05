{
  mkShell,
  pkgs,
  qt6,

  ...
}:
mkShell {
  buildInputs = with pkgs; [
    pkg-config
    cmake
    ninja

    # Rust
    (rust-bin.stable.latest.default.override {
      extensions = [
        "clippy"
        "rust-src"
      ];
    })
    cargo
    rustc
  ];

  ENV_QT_INCLUDE_PATH = "${qt6.qtdeclarative}/include";
  # NIX_CFLAGS_COMPILE = [
  #   "-I${qt6.qtbase}/include"
  #   "-I${qt6.qtbase}/include/QtQml"
  #   "-I${qt6.qtdeclarative}/include"
  #   "-I${qt6.qtdeclarative}/include/QtQml"
  #   "-U_FORTIFY_SOURCE"
  # ];
  QML2_IMPORT_PATH = builtins.concatStringsSep ":" [
    "${qt6.qtdeclarative}/lib/qt-6/qml"
    # "${kdePackages.qqc2-breeze-style}/lib/qt-6/qml"
    # "${kdePackages.kguiaddons}/lib/qt-6/qml"
  ];
  QT_QPA_PLATFORM_PLUGIN_PATH = "${qt6.qtbase}/${qt6.qtbase.qtPluginPrefix}/platforms";
  QT_PLUGIN_PATH = "${qt6.qtbase}/${qt6.qtbase.qtPluginPrefix}";

  shellHook = ''
    echo "🧪 dev"
  '';
}
