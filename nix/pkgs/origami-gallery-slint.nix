{
  craneLib,
  pkg-config,
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
    pname = "origami-gallery-slint";
    version = "0.1.0";
    cargoExtraArgs = "-p origami-gallery-slint";

    nativeBuildInputs = [
      pkg-config
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
