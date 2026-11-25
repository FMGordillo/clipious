{
  lib,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
  mpv,
  mpv-unwrapped,
  webkitgtk_4_1,
  gtk3,
  pkg-config,
  fetchzip,
  alsa-lib,
  libpulseaudio,
}: let
  versionLine = lib.findFirst (lib.hasPrefix "version:") (throw "Missing version in pubspec.yaml") (lib.splitString "\n" (builtins.readFile ../pubspec.yaml));

  # Prefetched so cmake does not download during the sandbox build.
  ffmpegKitLinux = fetchzip {
    url = "https://github.com/sk3llo/ffmpeg_kit_flutter/releases/download/8.1.2-full/ffmpeg-kit-linux-x86_64-full-8.1.2.tar.gz";
    hash = "sha256-MtL1pxCBzo1TyThGHrk7bTRcYa2uYhBk8ilE+rymFQ4=";
  };
in
  flutter.buildFlutterApplication rec {
    pname = "clipious";
    version = lib.head (lib.splitString "+" (lib.trim (lib.removePrefix "version:" versionLine)));

    src = lib.cleanSourceWith {
      src = ../.;
      filter = path: type: let
        base = baseNameOf path;
      in
        !(builtins.elem base [
          ".git"
          ".devenv"
          ".direnv"
          "build"
          ".dart_tool"
          "android"
          "ios"
          "macos"
          "windows"
          "web"
          "result"
        ]);
    };

    pubspecLock = lib.importJSON ./pubspec-lock.json;

    gitHashes = {
      river_player = "sha256-mmDK2C2Etdrpe/JBSzEaPz3Ng1pQKWiyrc7nYCVKcNk=";
      receive_sharing_intent = "sha256-8D5ZENARPZ7FGrdIErxOoV3Ao35/XoQ2tleegI42ZUY=";
    };

    runtimeDependencies = [
      mpv
      mpv-unwrapped
      webkitgtk_4_1
    ];

    nativeBuildInputs = [copyDesktopItems pkg-config];
    buildInputs = [
      webkitgtk_4_1
      gtk3
      alsa-lib
      libpulseaudio
      mpv-unwrapped
    ];

    desktopItems = [
      (makeDesktopItem {
        name = "clipious";
        exec = "clipious";
        icon = "clipious";
        desktopName = "Clipious";
        genericName = "Invidious client";
        comment = "Privacy-focused YouTube client via Invidious";
        categories = ["AudioVideo" "Player" "Network"];
      })
    ];

    # Flutter 3.44 + dartConfigHook can leave package_graph.json incomplete.
    # Ship a graph from `flutter pub get`. Point ffmpeg_kit at a fixed-output bundle.
    preBuild = ''
      mkdir -p .dart_tool
      cp ${./package_graph.json} .dart_tool/package_graph.json
      export FFMPEGKIT_LOCAL_DIR=${ffmpegKitLinux}
    '';

    postInstall = ''
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp ${../assets/icon-with-background.png} $out/share/icons/hicolor/256x256/apps/clipious.png
      if [ -x "$out/bin/invidious" ] && [ ! -e "$out/bin/clipious" ]; then
        ln -s invidious "$out/bin/clipious"
      fi
    '';

    meta = with lib; {
      description = "Invidious client for Linux desktop";
      homepage = "https://github.com/FMGordillo/clipious";
      license = licenses.agpl3Plus;
      platforms = ["x86_64-linux"];
      mainProgram = "clipious";
    };
  }
