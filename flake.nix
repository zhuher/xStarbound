{
  description = "Fork of OpenStarbound and successor to xSB-2";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, ... }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSupportedSystem' =
        systems: f:
        inputs.nixpkgs.lib.genAttrs systems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
            inherit system;
          }
        );
      forEachSupportedSystem = forEachSupportedSystem' supportedSystems;
    in
    {
      packages = forEachSupportedSystem (
        {
          pkgs,
          system,
        }:
        rec {
          xstarbound-unwrapped = pkgs.callPackage ./nix/unwrapped.nix { };
          xstarbound-debug = pkgs.callPackage ./nix/unwrapped.nix { debug = true; };
          xstarbound = pkgs.callPackage ./nix/package.nix { inherit xstarbound-unwrapped; };
          default = xstarbound;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          # meta package for garnix which can't support legacyPackages; do not use!
          _allMods = pkgs.linkFarmFromDrvs "xstarbound-allMods" (
            pkgs.lib.pipe self.legacyPackages.${system}.mods [
              (
                mods:
                builtins.removeAttrs mods [
                  "overrideDerivation"
                  "override"
                  "__functor"
                ]
              )
              builtins.attrValues
            ]
          );
        }
      );

      nixosModules = {
        xstarbound = import ./nix/module.nix self;
        default = self.nixosModules.xstarbound;
      };

      legacyPackages = forEachSupportedSystem' [ "x86_64-linux" ] (
        {
          pkgs,
          system,
        }:
        {
          dirwrap = pkgs.callPackage ./nix/dirwrap.nix { };
          mods = pkgs.callPackage ./nix/mods.nix {
            inherit (self.legacyPackages.${system}) fetchStarboundMod dirwrap;
          };
          fetchFromSteamWorkshop = pkgs.callPackage ./nix/fetchFromSteamWorkshop { };
          fetchStarboundMod = pkgs.callPackage ./nix/fetchStarboundMod.nix {
            inherit (self.legacyPackages.${system}) fetchFromSteamWorkshop;
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
