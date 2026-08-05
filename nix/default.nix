{
  nixpkgs,
  ...
}@inputs:
let
  # https://github.com/numtide/go2nix/blob/main/flake.nix
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  forAllSystems =
    f:
    nixpkgs.lib.genAttrs systems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      f system pkgs
    );
in
{
  packages = forAllSystems (
    _: pkgs: rec {
      default = temp;
      temp = pkgs.callPackage ./pkgs/temp.nix { };
    }
  );
  devShells = forAllSystems (
    _: pkgs: {
      default = pkgs.callPackage ./dev.nix { };
    }
  );
  formatter = forAllSystems (
    _: pkgs:
    let
      treefmt = import ./formatter.nix { inherit pkgs inputs; };
    in
    treefmt.wrapper
  );
}
