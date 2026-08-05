{
  rustPlatform,
  pkg-config,
  cmake,
  qt6,
  kdePackages,
}:
rustPlatform.buildRustPackage {
  pname = "origami";
  version = "0.1.0";

  src = ../..;

  cargoLock = {
    lockFile = ../../Cargo.lock;
    outputHashes = {
      "qtbridge-0.1.5" = "sha256-JmrL0wa0c2GKLxRDQ+5r9WXt0nUFDw5CvWqM8vqSSBs=";
    };
  };
  cargoBuildFlags = [ "--bin cettila" ];

  nativeBuildInputs = [
    pkg-config
    cmake
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qmake
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtsvg
    qt6.qtdeclarative
    qt6.qtwebengine

    kdePackages.qqc2-breeze-style
    kdePackages.kirigami
    kdePackages.kguiaddons
  ];

  env = {
    ENV_QT_INCLUDE_PATH = "${qt6.qtdeclarative}/include";
  };

  NIX_CFLAGS_COMPILE = [
    "-I${qt6.qtbase}/include"
    "-I${qt6.qtbase}/include/QtQml"
    "-I${qt6.qtdeclarative}/include"
    "-I${qt6.qtdeclarative}/include/QtQml"
    "-U_FORTIFY_SOURCE"
  ];

  postInstall = ''
    mkdir -p $out/share/applications
    cp $src/app/desktop/assets/*.desktop $out/share/applications/
  '';
}
