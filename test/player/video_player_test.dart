import 'package:clipious/app/states/app.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/player/states/video_player.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/videos/models/video.dart';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<MediaEvent> events = [];

  SilentPlayerCubit(super.initialState, super.settings);

  @override
  void setEvent(MediaEvent event) {
    events.add(event);
  }
}

class TestVideoPlayerCubit extends VideoPlayerCubit {
  final BetterPlayerController Function(BetterPlayerConfiguration)?
  controllerFactory;

  TestVideoPlayerCubit(
    super.initialState,
    super.player,
    super.settings, {
    this.controllerFactory,
  });

  @override
  void onInit() {}

  @override
  BetterPlayerController createVideoController(
    BetterPlayerConfiguration configuration,
  ) =>
      controllerFactory?.call(configuration) ??
      super.createVideoController(configuration);
}

class FailingSetupController extends BetterPlayerController {
  int setupCalls = 0;
  BetterPlayerDataSource? _dataSource;

  FailingSetupController(super.configuration, {BetterPlayerDataSource? source})
    : _dataSource = source;

  @override
  BetterPlayerDataSource? get betterPlayerDataSource => _dataSource;

  @override
  Future setupDataSource(BetterPlayerDataSource betterPlayerDataSource) async {
    setupCalls++;
    _dataSource = betterPlayerDataSource;
    throw PlatformException(
      code: 'VideoError',
      message:
          'Video player had error androidx.media3.exoplayer.ExoPlaybackException: Source error',
      details: '',
    );
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  bool? isPlaying() => false;
}

class SubtitleTestController extends BetterPlayerController {
  @override
  final BetterPlayerDataSource betterPlayerDataSource;

  SubtitleTestController(this.betterPlayerDataSource)
    : super(const BetterPlayerConfiguration());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('catches VideoError on initial and subsequent playVideo', () async {
    await db.upsertServer(const Server(url: 'https://invidious.example'));
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    addTearDown(app.close);
    await app.initState();
    final settings = TestSettingsCubit(SettingsState.init(), app);
    addTearDown(settings.close);
    final player = SilentPlayerCubit(
      PlayerState(playQueue: ListQueue.from([])),
      settings,
    );
    addTearDown(player.close);
    late FailingSetupController controller;
    final video = Video(
      videoId: 'abc123',
      hlsUrl: 'https://cdn.example/video.m3u8',
      formatStreams: [],
      adaptiveFormats: [],
    );
    final failingCubit = TestVideoPlayerCubit(
      VideoPlayerState(
        colors: ColorScheme.fromSeed(seedColor: Colors.red),
        overFlowTextColor: Colors.white,
        key: GlobalKey(),
        video: video,
      ),
      player,
      settings,
      controllerFactory: (config) {
        controller = FailingSetupController(config);
        return controller;
      },
    );
    addTearDown(failingCubit.close);

    // Initial controller creation path
    await failingCubit.playVideo(false);
    expect(controller.setupCalls, 1);
    expect(player.events.last.state, MediaState.error);

    // Subsequent reuse path
    player.events.clear();
    await failingCubit.playVideo(false);
    expect(controller.setupCalls, 2);
    expect(player.events.last.state, MediaState.error);
  });

  test('catches VideoError when switching non-DASH resolution', () async {
    final player = cubit.player as SilentPlayerCubit;
    final controller = FailingSetupController(
      const BetterPlayerConfiguration(),
      source: BetterPlayerDataSource.network('https://cdn.example/360p.mp4'),
    );
    addTearDown(controller.dispose);
    cubit.videoController = controller;

    await cubit.selectResolution('https://cdn.example/720p.mp4');
    expect(controller.setupCalls, 1);
    expect(player.events.last.state, MediaState.error);
  });
}
