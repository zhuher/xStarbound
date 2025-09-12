self: {
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.programs.xstarbound;
  settingsFormat = pkgs.formats.json {};
in {
  options.programs.xstarbound = {
    enable = lib.mkEnableOption "xstarbound";
    package = lib.mkPackageOption self.packages.${pkgs.stdenv.hostPlatform.system} "xstarbound" {};
    includeSteamMods = lib.mkEnableOption "inclusion of steam mods";
    localMods = {
      enable = lib.mkEnableOption "inclusion of local mods";
      dir = lib.mkOption {
        type = lib.types.str;
        default = "/change/programs.xstarbound.localMods.dir/value/to/an/existing/dir/with/mod/folders"; # [INFO]: This will error with trying to open this dir
      };
    };
    bootconfig.settings = lib.mkOption {
      default = {};
      type = settingsFormat.type;
    };
    finalPackage = lib.mkOption {
      readOnly = true;
      default = cfg.package.override {
        bootconfig = settingsFormat.generate "xsbinit.config" cfg.bootconfig.settings;
      };
    };
  };
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        warnings = [
        ];
        assertions = lib.mkMerge [
          [
            {
              assertion = cfg.bootconfig.settings.storageDirectory != "";
              message = ''
                You seem to have not set storageDirectory to a writable and existing location.
                Configure programs.xstarbound.bootconfig.settings.storageDirectory to point to a folder with at most 1 nonexistent lowest level.
                             |--------these-exist--------|this-doesnt
                For example: /Users/username/.local/share/xStarbound
              '';
            }
          ]
        ];
        environment.systemPackages = [cfg.finalPackage];
        programs.xstarbound.bootconfig.settings = {
          storageDirectory = lib.mkDefault "";
          assetDirectories = lib.mkBefore (
            builtins.trace
            "xSB: Make sure xstarbound.bootconfig.assetDirectories includes the paths containing both Starbound and xStarbound assets."
            [
              # "../a-packed-pak-folder/"
              # "../an-unpacked-asset-folder/"
              # "/absolute/asset/folder/path/"
              # # Environment variables would not work, but you can use something like ${config.users.users."your-username".home} instead.
              # "$HOME/Library/Application Support/Steam/steamapps/common/Starbound/assets"
              # "$HOME/GOG Games/Starbound/game/assets"
              # "$HOME/.local/share/Steam/steamapps/common/Starbound/assets"
              # "$HOME/.local/share/xStarbound/assets"
              # "$HOME/.local/share/Starbound/assets"
              "./xSB Client.app/Contents/Resources/xsb-assets/" # Valid xSB asset location for the macOS wrapped app bundle
              "../xsb-assets/" # Valid xSB asset location on linux
            ]
          );
          assetsSettings = {
            pathIgnore = lib.mkDefault [];
            digestIgnore = lib.mkDefault [".*"];
          };
          defaultConfiguration = {
            allowAdminCommandsFromAnyone = lib.mkDefault false;
            anonymousConnectionsAreAdmin = lib.mkDefault false;
          };
        };
      }
      (lib.mkIf cfg.localMods.enable {
        programs.xstarbound.bootconfig.settings.assetDirectories = lib.mkAfter (
          builtins.map (el: "${cfg.localMods.dir}/${el}/") (
            builtins.filter (el: !lib.hasPrefix "." el) (
              builtins.attrNames (builtins.readDir "${cfg.localMods.dir}")
            )
          )
        );
      })
    ]
  );
}
