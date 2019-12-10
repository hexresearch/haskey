{ compiler ? (pkgs: pkgs.haskell.packages.ghc865) }:
let
  pkgs = import ./pkgs.nix { inherit config; };
  config = {
    allowBroken = true;
    packageOverrides = pkgs: rec {
      haskellPackages = (compiler pkgs).override { overrides = haskOverrides; };
    };
  };
  haskOverrides = new: old: rec {
    haskey = new.callPackage ./haskey.nix {};
    stm-hamt = new.callPackage ./stm-hamt.nix {};
  };
in {
  inherit pkgs;
  packages = { inherit (pkgs.haskellPackages) haskey; };
}
