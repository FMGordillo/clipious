import 'package:clipious/app/states/app.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/player/states/video_player.dart';
import 'package:clipious/settings/states/settings.dart';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:river_player/river_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:clipious/globals.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';

import '../test_app_cubit.dart';
import '../test_player_cubit.dart';
import '../test_settings_cubit.dart';

class FakeWakelock implements WakelockPlusPlatformInterface {
  bool _enabled = false;

  @override
  bool get isMock => true;

  @override
  Future<bool> get enabled async => _enabled;

  @override
  Future<void> toggle({required bool enable}) async => _enabled = enable;
}

// setEvent drives the audio-service media handler, which is not under test
class SilentPlayerCubit extends TestPlayerCubit {
  SilentPlayerCubit(super.initialState, super.settings);

  @override
  void setEvent(MediaEvent event) {}
}

class TestVideoPlayerCubit extends VideoPlayerCubit {
  TestVideoPlayerCubit(super.initialState, super.player, super.settings);

  @override
  void onInit() {}
}

void main() {
  late TestVideoPlayerCubit cubit;

  setUp(() async {
    db = await SembastSqfDb.createInMemory();
    wakelockPlusPlatformInstance = FakeWakelock();
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    await app.initState();
    final settings = TestSettingsCubit(SettingsState.init(), app);
    cubit = TestVideoPlayerCubit(
      VideoPlayerState(
        colors: ColorScheme.fromSeed(seedColor: Colors.red),
        overFlowTextColor: Colors.white,
        key: GlobalKey(),
      ),
      SilentPlayerCubit(PlayerState(playQueue: ListQueue.from([])), settings),
      settings,
    );
  });

  tearDown(() async => await db.close());

  test('keeps screen awake while video plays', () async {
    cubit.onVideoListener(BetterPlayerEvent(BetterPlayerEventType.play));

    expect(await WakelockPlus.enabled, isTrue);
  });

  test('releases screen wake lock when video is paused', () async {
    cubit.onVideoListener(BetterPlayerEvent(BetterPlayerEventType.play));
    expect(await WakelockPlus.enabled, isTrue);
    cubit.onVideoListener(BetterPlayerEvent(BetterPlayerEventType.pause));

    expect(await WakelockPlus.enabled, isFalse);
  });

  test('releases screen wake lock when video finishes', () async {
    cubit.onVideoListener(BetterPlayerEvent(BetterPlayerEventType.play));
    expect(await WakelockPlus.enabled, isTrue);
    cubit.onVideoListener(BetterPlayerEvent(BetterPlayerEventType.finished));

    expect(await WakelockPlus.enabled, isFalse);
  });
}
