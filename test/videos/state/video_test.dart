import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:clipious/app/states/app.dart';
import 'package:clipious/downloads/states/download_manager.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/service.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:clipious/videos/models/dislike.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/states/video.dart';

import '../../test_app_cubit.dart';
import '../../test_player_cubit.dart';
import '../../test_settings_cubit.dart';
import '../../utils/server.dart';

class FakeService extends Service {
  @override
  Future<Dislike> getDislikes(String videoId) async {
    throw Error();
  }
}

/// Service whose getVideo hangs until [completer] is completed.
class _HangingVideoService extends Service {
  final Completer<Video> completer;

  _HangingVideoService(this.completer);

  @override
  Future<Video> getVideo(String videoId, {Server? serverOverride}) =>
      completer.future;

  @override
  Future<bool> isLoggedIn() async => false;

  @override
  Future<Dislike> getDislikes(String videoId) async => Dislike(0);
}

void main() {
  group('Youtube dislike', () {
    setUp(() async {
      await setUpTestsForTestServer();
    });

    tearDown(() async {
      await cleanUpTestServer();
      // nock.cleanAll();
    });

    test('If youtube dislike is down, it should not break the video loading',
        () async {
      try {
        // using service that will fail on dislikes
        service = FakeService();

        bool loggedIn = await service.isLoggedIn();
        var settingsCubit = TestSettingsCubit(SettingsState.init(),
            TestAppCubit(AppState(0, null, HomeLayout())));

        // using youtube dislikes
        await settingsCubit.setUseReturnYoutubeDislike(true);

        PlayerCubit player =
            TestPlayerCubit(PlayerState(playQueue: ListQueue()), settingsCubit);
        var video = VideoCubit(
            VideoState(videoId: 'dQw4w9WgXcQ', isLoggedIn: loggedIn),
            DownloadManagerCubit(const DownloadManagerState(), player),
            player,
            settingsCubit);
        await video.onReady();

        // we shouldn't have any errors that would override displaying video info properly
        expect(video.state.error, '');
      } finally {
        service = Service();
      }
    });
  });

  group('isClosed guard', () {
    late Service originalService;

    setUp(() async {
      originalService = service;
      db = await SembastSqfDb.createInMemory();
    });

    tearDown(() async {
      service = originalService;
      await db.close();
    });

    test('VideoCubit does not emit after close (no StateError thrown)',
        () async {
      final completer = Completer<Video>();
      service = _HangingVideoService(completer);

      var settingsCubit = TestSettingsCubit(
        SettingsState.init(),
        TestAppCubit(AppState(0, null, HomeLayout())),
      );
      PlayerCubit player = TestPlayerCubit(
        PlayerState(playQueue: ListQueue()),
        settingsCubit,
      );

      // Constructor calls onReady() which awaits the hanging getVideo.
      var videoCubit = VideoCubit(
        VideoState(videoId: 'dQw4w9WgXcQ', isLoggedIn: false),
        DownloadManagerCubit(const DownloadManagerState(), player),
        player,
        settingsCubit,
      );

      // Close the cubit before the network call resolves.
      await videoCubit.close();

      // Complete the hanging future — isClosed guard should prevent any emit.
      completer
          .complete(const Video(videoId: 'dQw4w9WgXcQ', title: 'Test video'));

      // Yield to let any pending microtasks run.
      await Future.delayed(Duration.zero);

      // Reaching here without a StateError confirms the isClosed guard works.
      expect(videoCubit.isClosed, isTrue);
    });
  });
}
