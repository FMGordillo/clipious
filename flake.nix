{
  description = "Clipious — Invidious client (Linux desktop package)";

  inputs = {
    nixpkgs-build.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs-build,
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = f: nixpkgs-build.lib.genAttrs systems (system: f nixpkgs-build.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: rec {
      clipious = pkgs.callPackage ./nix/clipious-linux.nix {};
      default = clipious;
    });

    apps = forAllSystems (pkgs: rec {
      clipious = {
        type = "app";
        program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.clipious}/bin/clipious";
      };
      default = clipious;
    });

    homeManagerModules = rec {
      clipious = { config, lib, pkgs, ... }: {
        options.programs.clipious.enable = lib.mkEnableOption "Clipious";

        config = lib.mkIf config.programs.clipious.enable {
          home.packages = [self.packages.${pkgs.stdenv.hostPlatform.system}.default];
        };
      };
      default = clipious;
    };
  };
}
