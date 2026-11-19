# Android SDK / toolchain notes

Current: Flutter 3.44.3 (Dart 3.12), AGP 8.12.3, Gradle 8.13, Kotlin 2.2.20,
compileSdk 36, targetSdk 35, build-tools 36.0.0, NDK 28.2.13676358, iOS 14.

## Nix/devenv specifics

- `android.builder.sdkDownload=false` (`android/gradle.properties`): the Nix SDK is
  read-only, so AGP must not try to install components.
- `ndkVersion flutter.ndkVersion` (`android/app/build.gradle`) must match the Nix NDK.
  Revisit if Flutter's default NDK changes.
- The devenv android module sets `aapt2FromMavenOverride` (via `GRADLE_OPTS`) to the
  *first* build-tools entry. The 33.0.2 aapt2 cannot read android-35/36 resource tables
  ("RES_TABLE_TYPE_TYPE entry offsets overlap"), so `enterShell` in `devenv.nix`
  repoints it at build-tools 36.0.0. Keep `36.0.0` in `android.buildTools.version`
  and the same version in `buildToolsVersion` of `android/app/build.gradle`.
- `android.platforms.version` includes 33 because `awesome_notifications_core`
  still declares compileSdk 33. Drop it when that plugin is updated.

## Held-back packages (revisit when Flutter ships Dart >= 3.13 / material_ui)

- `auto_route` < 11.2.0, `dynamic_color` 1.x, `cached_network_image` 4.0.3: newer
  versions use the standalone `material_ui` package, whose widget types differ from
  Flutter 3.44's `material.dart` (e.g. `TabController`, `ColorScheme`).
- `freezed` 4.0.0-dev.3: 4.0.3 requires Dart 3.13.
- `dependency_overrides` `matcher`/`test_api`: pinned by `flutter_test`.
- `intl`: pinned by `flutter_localizations`.

## Pending

- Built-in Kotlin (`android.builtInKotlin`/`android.newDsl`): needs AGP 9 (+ Gradle 9);
  with AGP 8.12 flipping the flags fails on Kotlin metadata mismatch. Several plugins
  (awesome_notifications_core, downloadsfolder, dynamic_color, flutter_volume_controller,
  flutter_web_auth_2, receive_sharing_intent, river_player, simple_pip_mode,
  workmanager_android) still apply the Kotlin Gradle plugin.
- `simple_pip_mode` 2.0 needs compileSdk 37 + Kotlin 2.4 (not in the Nix SDK yet).
- `river_player` tracks upstream master (already latest); `receive_sharing_intent` is
  pinned to a commit on purpose (issue #344).
- Tests need `devenv up` (local Invidious on `localhost:3000`, login test/test). With it, 9 pass; 8 still fail because they need real YouTube or the public instance list (channel, playlist, video, subscription, `save public servers`). A stale `postmaster.pid` in `.devenv/state/postgres` makes `devenv up` fail; delete it.
- `.git-blame-ignore-revs` lists the formatting commit; enable with
  `git config blame.ignoreRevsFile .git-blame-ignore-revs`.
