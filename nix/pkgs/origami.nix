{
  craneLib,
  callPackage,

  #[ Dependencies ]
  pkg-config,
  cmake,
  qt6,
  llvmPackages,
}:
let
  src = ../..;
  qtToolchain = callPackage ../qt-toolchain.nix { inherit qt6; };
  commonArgs = rec {
    inherit src;
    pname = "origami";
    version = "0.1.0";

    dontWrapQtApps = true;
    cargoExtraArgs = "-p origami";

    nativeBuildInputs = [
      pkg-config
      cmake
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qmake
      llvmPackages.lld
    ];

    buildInputs = [
      qt6.qtbase
      qt6.qtdeclarative
    ];

    env = {
      ENV_QT_INCLUDE_PATH = "${qt6.qtdeclarative}/include";
      RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
    };

    preBuild = ''
      export QMAKE="${qtToolchain.qmakeWrapper}/bin/qmake-wrapper"
      if [ -d target ]; then
        find target -type f -exec sed -i "s|/build/[^/]*source|$PWD|g" {} + 2>/dev/null || true
      fi
    '';
  };
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
  commonArgs
  // {
    inherit cargoArtifacts;
    doCheck = false;
    postInstall = ''
      mkdir -p $out/lib/qt-6/qml/la/cettila/Ayame
      mkdir -p $out/lib/qt-6/qml/QtQuick/Controls/Ayame
      if [ -d crates/qml6/qml ]; then
        cp -r crates/qml6/qml/* $out/lib/qt-6/qml/la/cettila/Ayame/
        cp -r crates/qml6/qml/* $out/lib/qt-6/qml/QtQuick/Controls/Ayame/
      fi
      qmldir_file=$(find target -name qmldir 2>/dev/null | head -n 1)
      if [ -n "$qmldir_file" ]; then
        cp "$qmldir_file" $out/lib/qt-6/qml/la/cettila/Ayame/qmldir
        cp "$qmldir_file" $out/lib/qt-6/qml/QtQuick/Controls/Ayame/qmldir
      fi
    '';
  }
)
