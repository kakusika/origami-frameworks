{
  flake-parts,
  ...
}@inputs:
flake-parts.lib.mkFlake { inherit inputs; } {
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    { pkgs, ... }:
    let
      craneLib = inputs.crane.mkLib pkgs;
    in
    {
      packages = rec {
        default = origami-gallery;
        origami-gallery = pkgs.callPackage ./pkgs/origami-gallery.nix { inherit craneLib; };
      };

      devShells.default = pkgs.callPackage ./dev.nix {
        inherit inputs craneLib;
      };

      treefmt = import ./formatter.nix;
    };
}
