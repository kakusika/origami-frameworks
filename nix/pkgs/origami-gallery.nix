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
    pname = "origami-gallery";
    version = "0.1.0";

    dontWrapQtApps = true;
    cargoExtraArgs = "-p origami-gallery";

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
  }
)
