# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dev environment (nix-based, pins Flutter submodule)
nix-shell

# Initialize submodules (Flutter is a git submodule)
git submodule init && git submodule update

# Run tests
./submodules/flutter/bin/flutter test

# Run a single test file
./submodules/flutter/bin/flutter test test/path/to/test_file.dart

# Format (CI enforces this)
dart format ./lib

# Analyze (CI enforces, warnings non-fatal)
dart analyze --no-fatal-warnings ./lib

# Code generation (freezed models, auto_route, json_serializable)
make build-runner
# or watch mode:
make build-runner-watch

# Build APK
./submodules/flutter/bin/flutter build apk --profile --split-per-abi
```

## Architecture

### State Management — BLoC/Cubit

Every feature folder has a `states/` directory with Cubits. Global cubits (`AppCubit`, `SettingsCubit`, `PlayerCubit`, `DownloadManagerCubit`) are initialized in `main()` via `MultiBlocProvider`. Feature-level cubits are provided closer to the widget tree.

### Feature Structure

Each feature (channels, videos, downloads, player, playlists, search, etc.) follows:

```
feature/
  models/     # freezed + json_serializable data classes
  states/     # BLoC Cubits
  views/      # Phone/tablet UI
  views/tv/   # Android TV UI (separate widget trees)
```

### Routing

`auto_route` with definitions in `lib/router.dart`. Generated file is `lib/router.gr.dart` — do not edit manually, regenerate with `make build-runner`.

### Database

Dual backend abstracted via `lib/utils/interfaces/db.dart`:
- `SembastSqfDb` — Sembast + SQLite hybrid
- `FileDB` — file-based persistence

Initialized before the router in `main()`. Global instance at `lib/globals.dart`.

### API Client

`lib/service.dart` is the Invidious API client (~800+ lines). Handles:
- Video/channel/playlist/subscription endpoints
- SponsorBlock + DeArrow integration
- Return YouTube Dislikes API
- OAuth2 auth via `flutter_web_auth_2`

### Media Playback

- `just_audio` — audio-only playback
- `river_player` (custom git dependency in `submodules/`) — video
- `audio_service` + `workmanager` — background playback
- `ffmpeg_kit_flutter_new_full` — download/transcoding

### Code Generation

Models use `freezed` + `json_serializable`. After modifying any model annotated with `@freezed` or `@JsonSerializable`, run `make build-runner`. Generated files end in `.freezed.dart` or `.g.dart` — do not edit.

### Localization

ARB files in `lib/l10n/`. Generated output in `lib/l10n/generated/`. Add new strings to the base ARB file; translations managed via Weblate.

### TV vs Mobile UI

Components in `views/tv/` are parallel implementations for Android TV. When changing UI behavior, check if a TV counterpart exists and needs the same change.
