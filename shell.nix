{ compiler ? (pkgs: pkgs.haskell.packages.ghc865) }:
let
  release = import ./nix/release.nix { inherit compiler; };
  pkgs = release.pkgs;
in pkgs.haskellPackages.shellFor {
  nativeBuildInputs = with pkgs.haskellPackages; [
    cabal-install
    ghcid
  ];
  packages = _: pkgs.lib.attrValues release.packages;
}
