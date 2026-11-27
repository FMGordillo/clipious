# Clipious

[![license agpl v3](https://shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.en.html)
Android client application for [invidious](https://invidious.io), the privacy focused youtube front end

[![Build Status](https://drone.ftpix.com/api/badges/lamarios/clipious/status.svg)](https://drone.ftpix.com/lamarios/clipious)

## Community

[Join the matrix channel](https://matrix.to/#/#clipious:matrix.org)

## License

Copyright (C) 2023 Paul Fauchon

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

## Features

- Use own or public  server
- Subscription management
- SponsorBlock + DeArrow (click bait removal)
- Video view/progress tracking
- Playlists
- background playback
- Live stream support
- Android TV ui
- Audio playback
- Video / audio download
- Video filtering
- Return YouTube dislikes

## Installation
The best way to install is to get it directly from the [GitHub releases page](https://github.com/FMGordillo/clipious/releases/latest). Using [Obtainium](https://github.com/ImranR98/Obtainium) can help keeping the app up to date.

Each release ships one APK per CPU. Pick the one for your device:

| Device | APK |
|---|---|
| Most phones and tablets | `app-arm64-v8a-release.apk` |
| Chromecast with Google TV (and other 32-bit Android TV devices) | `app-armeabi-v7a-release.apk` |
| x86_64 emulators | `app-x86_64-release.apk` |

Not sure which one you need? Run `adb shell getprop ro.product.cpu.abilist` on the device: `arm64-v8a` in the output means the arm64 build, otherwise use armeabi-v7a. Obtainium's APK filter can select one file automatically.

It is also available on F-Droid, IzzyOnDroid, and Accrescent:

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/com.github.lamarios.clipious/)
[<img src="https://accrescent.app/badges/get-it-on.png"
      alt='Get it on Accrescent'
      height="80">](https://accrescent.app/app/com.github.lamarios.clipious)

Or download the latest APK from the [Releases Section](https://github.com/FMGordillo/clipious/releases/latest).

### TV

For TV users it is recommended to use [Accrescent](https://accrescent.app) as it works well enough on TV and allows updates. If you sideload from GitHub instead, use the `armeabi-v7a` APK from the table above; the arm64 APK will not install on those devices.

## Screenshots
### Phone
[![Home](./screenshots/mobile-home_small.png)](./screenshots/mobile-home.png)
[![Video](./screenshots/mobile-video_small.png)](./screenshots/mobile-video.png)
[![Channel](./screenshots/mobile-channel_small.png)](./screenshots/mobile-channel_small.png)
[![Playlist](./screenshots/mobile-playlist_small.png)](./screenshots/mobile-playlist_small.png)

### Tablet

[![Home](./screenshots/tablet-home_small.png)](./screenshots/tablet-home.png)
[![Video](./screenshots/tablet-video_small.png)](./screenshots/tablet-video.png)
[![Channel](./screenshots/tablet-channel_small.png)](./screenshots/tablet-channel_small.png)
[![Playlist](./screenshots/tablet-playlist_small.png)](./screenshots/tablet-playlist_small.png)

### TV

[![Home](./screenshots/tv-home_small.png)](./screenshots/tv-home.png)
[![Home](./screenshots/tv-home-2_small.png)](./screenshots/tv-home-2.png)
[![Video](./screenshots/tv-video_small.png)](./screenshots/tv-video.png)
[![Video](./screenshots/tv-video-2_small.png)](./screenshots/tv-video-2.png)
[![Channel](./screenshots/tv-channel_small.png)](./screenshots/tv-channel_small.png)
[![Playlist](./screenshots/tv-playlist_small.png)](./screenshots/tv-playlist_small.png)
[![Playlist](./screenshots/tv-playlist-2_small.png)](./screenshots/tv-playlist_small-2.png)

## Facing an issue ? 

- Check the [Common issue wiki page](https://github.com/lamarios/clipious/wiki/Common-Issues)
- Open an issue

## Contribute

### Code

The project uses [devenv](https://devenv.sh) (Nix-based) to provide a fully reproducible environment including the Android SDK, Flutter, PostgreSQL, and a local Invidious instance.

#### 1. Enter the dev environment

```bash
devenv shell
```

This gives you the correct Flutter, Android SDK, `adb`, and all required tools.

#### 2. One-time setup

Run once after cloning to configure the Flutter JDK and fetch dependencies:

```bash
setup
```

Entering `devenv shell` installs the pre-commit hooks. Commit from that shell so
the hooks can check formatting on staged Dart files (excluding generated code)
and analyze app code without starting backend services. Use `dart format <file>`
if a staged file fails the format check, then stage it again.

#### 3. Start the local Invidious backend

Integration tests rely on a local Invidious server with a seeded test user. Start it with:

```bash
devenv up
```

This spins up PostgreSQL on port 5433, runs the Invidious migrations, and seeds a test account (username `test`, password `test`).

#### 4. Run the tests

```bash
flutter test
```

GitHub Actions analyzes app code, runs offline tests, and builds a Linux debug
app on pushes and pull requests to `master`. It does not need local Invidious.

In `FMGordillo/clipious`, pushes to `master` build signed APKs per Android ABI
and publish a `ci-<run number>` prerelease under
[GitHub Releases](https://github.com/FMGordillo/clipious/releases). Pushing a
`v*` tag publishes a full release with the signed APKs and SHA1 checksums.
Pull requests do not build or publish these APKs.

Run `./release.sh` (or `./release.sh major|minor|patch` to choose the bump) to
update the version, commit it, and push the version tag. CI handles the build,
signing, and publication; you do not need a local keystore.

To enable signing, add these repository secrets under **Settings → Secrets and
variables → Actions**:

- `ANDROID_KEYSTORE_BASE64`: run `base64 -w0 /path/to/your-release-keystore`.
  Use the existing release keystore so the APKs can update existing installs.
- `ANDROID_KEY_PROPERTIES_BASE64`: run `base64 -w0 android/key.properties`.
  The file must contain `storePassword`, `keyPassword`, and `keyAlias` for that
  keystore. CI overrides `storeFile` to point to the decoded keystore.

Do not commit either file or its encoded contents.

#### 5. Run on a device

Enable *Developer Options → USB Debugging* on your Android device, connect it via USB, then:

```bash
# Verify the device is visible
adb devices

# Build and run with hot-reload
flutter run

# Or build a profile APK and install manually
flutter build apk --profile --split-per-abi
adb install build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk
```

Use `--profile` rather than `--debug` when testing media playback — the native video/audio layers behave closer to a release build.

#### Available scripts

| Script | Description |
|---|---|
| `setup` | One-time setup |
| `clipious gen` | Pub get + code generation (`freezed`, `auto_route`, `json_serializable`) |
| `clipious watch` | Watch mode for code generation |
| `clipious apk [debug\|profile\|release]` | Universal APK (default debug) |
| `clipious apk-split [mode]` | Per-ABI release APKs for mobile and Android TV (default release) |
| `clipious linux [mode]` | Linux desktop build (default debug) |
| `clipious test` / `fmt` / `lint` | Test, format, analyze |

Run `clipious` with no args for the full list.

### Linux desktop (local fork)

Dev run (inside `devenv shell`):

```bash
flutter run -d linux
# or
clipious linux          # debug build → build/linux/
clipious linux release
```

Nix package (x86_64-linux):

```bash
nix build .#clipious
nix run .#clipious
```

For flake-based Home Manager on `x86_64-linux`, add `inputs.clipious.url = "github:FMGordillo/clipious";` to your flake. With `clipious` in scope from your flake inputs, add this to your Home Manager modules (not your NixOS system modules):

```nix
{
  imports = [ clipious.homeManagerModules.default ];
  programs.clipious.enable = true;
}
```

Playback uses `media_kit` on Linux. Downloads, PiP, share-intent, and background sync are disabled. After changing Dart dependencies, refresh `nix/package_graph.json` from `.dart_tool/package_graph.json` (`flutter pub get`).

After updating `pubspec.lock`, regenerate the Nix lock data with `nix shell nixpkgs#yq --command yq . pubspec.lock > nix/pubspec-lock.json`.

### Translations

![Translation status](https://hosted.weblate.org/widgets/clipious/-/app-translation/multi-auto.svg)

The translations are done via [weblate](https://hosted.weblate.org/projects/clipious/app-translation/).

## Liability

We take no responsibility for the use of our tool, or external instances
provided by third parties. We strongly recommend you abide by the valid
official regulations in your country. Furthermore, we refuse liability
for any inappropriate use of Invidious, such as illegal downloading.
This tool is provided to you in the spirit of free, open software.

You may view the LICENSE in which this software is provided to you [here](./LICENSE).

>   16. Limitation of Liability.
>
> IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
>

