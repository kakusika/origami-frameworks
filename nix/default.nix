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
        inherit inputs;
        fenix = inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system};

        tomet = inputs.tomet.packages.${pkgs.stdenv.hostPlatform.system}.tomet;
        tomet-lsp = inputs.tomet.packages.${pkgs.stdenv.hostPlatform.system}.tomet-lsp;
        tmtbook = inputs.tomet-book.packages.${pkgs.stdenv.hostPlatform.system}.tmtbook;
        twrit = inputs.twrit.packages.${pkgs.stdenv.hostPlatform.system}.twrit;
      };

      treefmt = import ./formatter.nix {
        inherit pkgs;
        tomet = inputs.tomet.packages.${pkgs.stdenv.hostPlatform.system}.tomet;
      };
    };
}
