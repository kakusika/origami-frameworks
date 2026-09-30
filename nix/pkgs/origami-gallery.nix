{
  craneLib,
  pkg-config,
  python3,
  ninja,
  clang,
  fontconfig,
  freetype,
  wayland,
  libxkbcommon,
  libGL,
  vulkan-loader,
}:
let
  src = ../..;
  commonArgs = {
    inherit src;
    pname = "origami-gallery";
    version = "0.1.0";
    cargoExtraArgs = "-p origami-gallery";

    nativeBuildInputs = [
      pkg-config
      python3
      ninja
      clang
    ];

    buildInputs = [
      fontconfig
      freetype
      wayland
      libxkbcommon
      libGL
      vulkan-loader
    ];
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
