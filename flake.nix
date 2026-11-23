{
  description = "Clipious — Invidious client (Linux desktop package)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: rec {
      clipious = pkgs.callPackage ./nix/clipious-linux.nix {};
      default = clipious;
    });

    apps = forAllSystems (pkgs: rec {
      clipious = {
        type = "app";
        program = "${self.packages.${pkgs.system}.clipious}/bin/clipious";
      };
      default = clipious;
    });
  };
}
