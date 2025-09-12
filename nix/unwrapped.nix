{
  steamIntegration ? true,
  nativeComp ? true,
  packageAssets ? nativeComp,
  lib,
  stdenv,
  cmake,
  ninja,
  zlib,
  libpng,
  freetype,
  libvorbis,
  libopus,
  SDL2,
  glew,
  libsm,
  libxi,
  xxhash,
  cctools,
  patchelf,
  impureUseNativeOptimizations,
}: let
  binPath =
    if stdenv.isDarwin
    then "xSB Client.app/Contents/MacOS"
    else "linux";
  fs = lib.fileset;
  steamApiPlatform =
    if stdenv.isDarwin
    then "macos"
    else "linux/x86_64";
  steamApi = builtins.path {
    recursive = true;
    name = "xstarbound-steam-api";
    filter = _: _: true;
    path = ../source/extern/steam/lib/${steamApiPlatform};
  };
  steamApiLib = "libsteam_api.${
    if stdenv.isDarwin
    then "dylib"
    else "so"
  }";
in
  ((
      if nativeComp
      then impureUseNativeOptimizations
      else (x: x)
    )
    stdenv).mkDerivation {
    pname = "xstarbound";
    # parse version # from CMakeLists.txt. This might be brittle and show a very wonky version
    # in the future, but it's better than someone forgetting to update it.
    version = let
      lines = builtins.split "\n" (builtins.readFile ../CMakeLists.txt);
      prefix = "set(XSB_VERSION ";
      suffix = ")";
      statement = lib.findFirst (line: !(builtins.isList line) && lib.hasPrefix prefix line) null lines;
    in
      lib.pipe statement [
        (lib.removePrefix prefix)
        (lib.removeSuffix suffix)
      ];
    src = fs.toSource rec {
      root = ../.;
      fileset = fs.difference root (
        fs.unions [
          ### FILES TO EXCLUDE ###

          # Technically, this list of path exclusions could be more aggressive,
          # since Nix doesn't require nearly all build files residing in this repo.
          # But this would require gutting out these paths in the project CMakeList,
          # which seems like a lot of work for questionable gain.

          # xStarbound helper files for "normal" OSes
          ../lib # windows stuff
          # ../macos # [INFO]: required by Install.cmake on MacOS

          # unused
          ../source/extern/old_lua

          # vcpkg (package manager files not used by Nix)
          ../vcpkg.json
          ../vcpkg-configuration.json

          # git
          ../.gitattributes
          ../.github
          ../.gitignore
          ../.gitmodules

          # IDE
          ../.vscode

          # Nix
          ./.
          ../flake.nix
          ../flake.lock

          # Code project FILES
          ../README.md
        ]
      );
    };
    cmakeFlags = [
      (lib.cmakeBool "STAR_ENABLE_STEAM_INTEGRATION" steamIntegration)
      (lib.cmakeBool "PACKAGE_XSB_ASSETS" packageAssets)
      (lib.cmakeBool "STAR_USE_EXTERN_XXHASH" false) # [INFO]: the <flakeRoot>/source/extern/xxhash includes x86 code and crashes during native arm64 compilation
    ];
    # NB: This code specifically passes libopus to the linker. At the time of writing (2025-09-22),
    # the reason for why we have to do this is unknown. All other libraries gets automatically passed by
    # existing in nativeBuildInputs, but not libopus. This hack makes the build logs very noisy and it's not
    # very elegant, so if any future readers know what the issue might be, please improve this.
    env.LDFLAGS = "-Wl,-rpath,${libopus}/lib -lopus -Wl,-w"; # '-w' suppresses all warnings
    env.CXXFLAGS = "-w"; # ditto
    nativeBuildInputs =
      [
        cmake
        ninja
        zlib
        libpng
        freetype
        libvorbis
        libopus
        SDL2
        glew
        xxhash
      ]
      ++ lib.optionals stdenv.isLinux [
        libsm
        libxi
      ]
      # cctools is for fixing relative dylib reference to steamapi
      ++ lib.optionals stdenv.isDarwin [cctools];

    buildInputs =
      lib.optionals steamIntegration [steamApi];

    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail "-flto " ""
    '';

    preInstall = ''
      ${(lib.optionalString (stdenv.isDarwin && steamIntegration) ''
        ${cctools}/bin/install_name_tool -change @loader_path/${steamApiLib} "${steamApi}/${steamApiLib}" "source/client/xclient"
        ${cctools}/bin/install_name_tool -add_rpath "${steamApi}" "source/client/xclient"
      '')}
    '';
    postInstall = ''
      mkdir -p "$out/bin"
      ${lib.optionalString stdenv.isDarwin ''
        mkdir -p "$out/Applications"
        ln -s "$out/xSB Client.app" "$out/Applications/"
      ''}
      ln -s "$out/${binPath}"/* "$out/bin/"
      mv "$out/bin/x"{client,starbound}
      ${
        lib.optionalString packageAssets
        ''
          for dir in ../assets/*/; do
            if [ -d "$dir" ]; then
              $out/bin/asset_packer "$dir" "$out/${binPath}/../${
            lib.optionalString stdenv.isDarwin "Resources/"
          }xsb-assets/$(basename "$dir").pak"
            fi
          done
        ''
      }
    '';
    postFixup = ''
      ${lib.optionalString (stdenv.isLinux && steamIntegration) ''
        ${lib.getExe patchelf} --replace-needed ${steamApiLib} "${steamApi}/${steamApiLib}" "$out/bin/xstarbound"
      ''}
    '';

    meta.mainProgram = "xstarbound";
  }
