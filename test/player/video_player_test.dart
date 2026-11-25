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
import 'package:river_player/src/video_player/video_player.dart';
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

class SubtitleTestController extends BetterPlayerController {
  @override
  final BetterPlayerDataSource betterPlayerDataSource;

  SubtitleTestController(this.betterPlayerDataSource)
    : super(const BetterPlayerConfiguration());
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

  test('ignores seek before video initialization', () {
    cubit.videoController = BetterPlayerController(
      const BetterPlayerConfiguration(),
    )..videoPlayerController = VideoPlayerController(autoCreate: false);

    cubit.seek(const Duration(seconds: 1));
  });

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

  test('removes only inline timestamps from Invidious cues', () async {
    const firstLine = 'HalfLife<00:00:05.359> 2<00:06.480> <i>barrel</i>';
    const secondLine = 'Preserve &lt;00:06.480&gt; and <b>formatting</b>';
    BetterPlayerSubtitlesSource track(
      String name,
    ) => BetterPlayerSubtitlesSource(
      type: BetterPlayerSubtitlesSourceType.memory,
      name: name,
      content:
          'WEBVTT\n\n00:00:05.000 --> 00:00:09.000\n$firstLine\n$secondLine',
    );

    final invidious = track('English');
    final controller = SubtitleTestController(
      BetterPlayerDataSource.network(
        'https://example.com/video',
        subtitles: [invidious],
      ),
    )..addEventsListener(cubit.onVideoListener);
    addTearDown(controller.dispose);
    cubit.videoController = controller;

    Future<void> select(BetterPlayerSubtitlesSource source) async {
      final saved = cubit.settings.stream.firstWhere(
        (state) => state.lastSubtitles == source.name,
      );
      await controller.setupSubtitleSource(source, sourceInitialize: true);
      await saved;
    }

    await select(invidious);
    final cue = controller.subtitlesLines.single;
    expect(cue.start, const Duration(seconds: 5));
    expect(cue.end, const Duration(seconds: 9));
    expect(cue.texts, ['HalfLife 2 <i>barrel</i>', secondLine]);

    await select(track('Manifest track'));
    expect(controller.subtitlesLines.single.texts, [firstLine, secondLine]);
  });
}
