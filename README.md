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
The best way to install is to get it directly from the release page. Using [Obtainium](https://github.com/ImranR98/Obtainium) can help keeping the app up to date.

It is also available on F-Droid, IzzyOnDroid, and Accrescent:

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png"
     alt="Get it on F-Droid"
     height="80">](https://f-droid.org/packages/com.github.lamarios.clipious/)
[<img src="https://accrescent.app/badges/get-it-on.png"
      alt='Get it on Accrescent'
      height="80">](https://accrescent.app/app/com.github.lamarios.clipious)

Or download the latest APK from the [Releases Section](https://github.com/lamarios/clipious/releases/latest).

### TV

For TV users it is recommended to use [Accrescent](https://accrescent.app) as it works well enough on TV and allows updates.

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

This gives you the correct Flutter (pinned as a git submodule), Android SDK, `adb`, and all required tools.

#### 2. One-time setup

Run once after cloning (initialises submodules, configures the Flutter JDK, installs the pre-commit formatting hook):

```bash
setup
```

#### 3. Start the local Invidious backend

Tests rely on a locally running Invidious server with a seeded test user. Start it with:

```bash
devenv up
```

This spins up PostgreSQL on port 5433, runs the Invidious migrations, and seeds a test account (username `test`, password `test`). This is how tests are run in CI.

#### 4. Run the tests

```bash
flutter test
```

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
| `setup` | One-time setup (submodules, JDK config, git hooks) |
| `build-runner` | Run code generation once (`freezed`, `auto_route`, `json_serializable`) |
| `build-runner-watch` | Watch mode for code generation |

Flutter is included as a git submodule to pin the exact version used by F-Droid for reproducible builds. The `setup` script adds `./submodules/flutter/bin` to your `PATH` so plain `flutter` and `dart` commands use the pinned version.

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

