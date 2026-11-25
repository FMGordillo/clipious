import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:clipious/app/states/app.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/media_handler.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils/models/image_object.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app_cubit.dart';
import '../test_player_cubit.dart';
import '../test_settings_cubit.dart';

class MediaHandlerTestPlayer extends TestPlayerCubit {
  MediaHandlerTestPlayer(super.initialState, super.settings);

  @override
  bool get supportsMediaHandler => true;
}

class DelayedMediaHandlerPlayer extends PlayerCubit {
  DelayedMediaHandlerPlayer(super.initialState, super.settings);

  final initializingHandler = Completer<void>();
  final handler = Completer<MediaHandler>();
  late final Future<void> ready;

  @override
  bool get supportsMediaHandler => true;

  @override
  Future<void> onReady() => ready = super.onReady();

  @override
  Future<MediaHandler> initMediaHandler() {
    initializingHandler.complete();
    return handler.future;
  }
}

void main() {
  testWidgets('processes playback events without a media handler', (
    tester,
  ) async {
    db = await SembastSqfDb.createInMemory();
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    final settings = TestSettingsCubit(SettingsState.init(), app);
    final player = MediaHandlerTestPlayer(PlayerState.init(null), settings);
    addTearDown(player.close);
    addTearDown(settings.close);
    addTearDown(app.close);

    const event = MediaEvent(
      type: MediaEventType.play,
      state: MediaState.playing,
    );
    player.setEvent(event);

    expect(player.state.isPlaying, isTrue);
    expect(player.state.mediaEvent, event);
  });

  test('publishes the current video when the media handler is ready', () async {
    db = await SembastSqfDb.createInMemory();
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    final settings = TestSettingsCubit(SettingsState.init(), app);
    final video = Video(
      videoId: 'first',
      title: 'First video',
      formatStreams: const [],
      adaptiveFormats: const [],
      videoThumbnails: [
        ImageObject(null, 'https://example.com/first.jpg', 1, 1),
      ],
    );
    final player = DelayedMediaHandlerPlayer(
      PlayerState.init([video]),
      settings,
    );
    addTearDown(player.close);
    addTearDown(settings.close);
    addTearDown(app.close);

    await player.initializingHandler.future;
    await player.switchToVideo(video);
    player.setEvent(
      const MediaEvent(type: MediaEventType.play, state: MediaState.playing),
    );
    expect(player.state.currentlyPlaying, video);

    final handler = MediaHandler(player);
    player.handler.complete(handler);
    await player.ready;
    await Future<void>.delayed(Duration.zero);

    expect(handler.mediaItem.value?.id, video.videoId);
    expect(handler.mediaItem.value?.title, video.title);
    expect(
      handler.mediaItem.value?.artUri,
      Uri.parse(video.videoThumbnails.single.url),
    );
    expect(handler.playbackState.value.playing, isTrue);
    expect(
      handler.playbackState.value.processingState,
      AudioProcessingState.ready,
    );
    expect(handler.playbackState.value.queueIndex, 0);
  });
}
