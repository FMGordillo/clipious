import 'dart:collection';

import 'package:clipious/app/states/app.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app_cubit.dart';
import '../test_player_cubit.dart';
import '../test_settings_cubit.dart';

class SpyPlayerCubit extends TestPlayerCubit {
  SpyPlayerCubit(super.initialState, super.settings);

  int playNextCalls = 0;

  @override
  void playNext() {
    playNextCalls++;
    super.playNext();
  }
}

void main() {
  testWidgets(
    'plays the next video only after the timeout when the current video completes',
    (tester) async {
      db = await SembastSqfDb.createInMemory();
      final app = TestAppCubit(AppState(0, null, HomeLayout()));
      await app.initState();
      final settings = TestSettingsCubit(SettingsState.init(), app);
      final cubit = SpyPlayerCubit(
        PlayerState(playQueue: ListQueue.from([])),
        settings,
      );

      cubit.handleMediaEvent(const MediaEvent(state: MediaState.completed));

      expect(
        cubit.playNextCalls,
        0,
        reason: 'the next video must not start immediately after completion',
      );

      await tester.pump(autoplayNextDelay);

      expect(
        cubit.playNextCalls,
        1,
        reason: 'the next video must start after the timeout',
      );

      // drain the throttle timer scheduled by playNext
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'cancels the pending autoplay when another video is started manually',
    (tester) async {
      db = await SembastSqfDb.createInMemory();
      final app = TestAppCubit(AppState(0, null, HomeLayout()));
      await app.initState();
      final settings = TestSettingsCubit(SettingsState.init(), app);
      final cubit = SpyPlayerCubit(
        PlayerState(playQueue: ListQueue.from([])),
        settings,
      );

      cubit.handleMediaEvent(const MediaEvent(state: MediaState.completed));
      cubit.playNext();
      await tester.pump(autoplayNextDelay + const Duration(seconds: 1));

      expect(
        cubit.playNextCalls,
        1,
        reason: 'the timeout must not fire a second time after a manual play',
      );
    },
  );
}
