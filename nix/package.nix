{
  xstarbound-unwrapped,
  bootconfig ? ./xsbinit.config,
  symlinkJoin,
  makeBinaryWrapper,
  stdenvNoCC,
  makeDesktopItem,
  lib,
  runCommand,
}: let
  binPath =
    if stdenvNoCC.isDarwin
    then "xSB Client.app/Contents/MacOS"
    else "linux";

  desktopItem = makeDesktopItem {
    name = "xstarbound";
    exec = "xstarbound %U";
    icon = "xstarbound";
    desktopName = "xStarbound";
    comment = "Fork of OpenStarbound - 2D sandbox adventure game";
    categories = ["Game" "AdventureGame"];
    keywords = ["game" "starbound" "xstarbound" "sandbox"];
  };

  iconSrc = ../source/client/xclient-largelogo.ico;
  iconSizes = ["16x16" "32x32" "48x48" "64x64" "128x128" "256x256" "512x512"];
in
  symlinkJoin {
    name = "xstarbound-wrapped";
    paths =
      [xstarbound-unwrapped]
      ++ lib.optionals stdenvNoCC.isLinux [
        desktopItem
        (runCommand "xstarbound-icons" {} ''
          mkdir -p $out/share/icons/hicolor
          ${lib.concatMapStringsSep "\n" (size: ''
              mkdir -p $out/share/icons/hicolor/${size}/apps
              cp ${iconSrc} $out/share/icons/hicolor/${size}/apps/xstarbound.png
            '')
            iconSizes}
        '')
      ];
    nativeBuildInputs = [makeBinaryWrapper];
    postBuild = ''
      wrapProgram $out/"${binPath}"/xclient \
      --add-flags '-bootconfig' \
      --add-flags '${bootconfig}'
    '';
  }
