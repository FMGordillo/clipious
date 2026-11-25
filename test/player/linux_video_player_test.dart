import 'dart:collection';
import 'dart:convert';

import 'package:clipious/app/states/app.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/player/states/linux_video_player.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/player/states/video_player.dart';
import 'package:clipious/service.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:clipious/videos/models/caption.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../test_app_cubit.dart';
import '../test_settings_cubit.dart';
import 'video_player_test.dart' show FakeWakelock, SilentPlayerCubit;

class _CaptionService extends Service {
  final Client _client;

  @override
  Client get httpClient => _client;

  _CaptionService(this._client);
}

class _PlatformPlayer extends PlatformPlayer {
  _PlatformPlayer() : super(configuration: const PlayerConfiguration());

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    state = state.copyWith(width: 640, height: 360);
  }

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Linux restores and disables Invidious subtitles', () async {
    const route = '/api/v1/captions/video?label=Fran%C3%A7ais';
    const cues = 'WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nÇa va ?';
    final requests = <Request>[];
    final originalService = service;
    final client = MockClient((request) async {
      requests.add(request);
      return Response.bytes(utf8.encode(cues), 200);
    });
    service = _CaptionService(client);
    addTearDown(() {
      client.close();
      service = originalService;
    });

    db = await SembastSqfDb.createInMemory();
    addTearDown(() async => await db.close());
    await db.upsertServer(
      const Server(
        url: 'https://invidious.example',
        customHeaders: {'Authorization': 'Basic test'},
      ),
    );
    final originalWakelock = wakelockPlusPlatformInstance;
    wakelockPlusPlatformInstance = FakeWakelock();
    addTearDown(() => wakelockPlusPlatformInstance = originalWakelock);
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    addTearDown(app.close);
    await app.initState();
    final settings = TestSettingsCubit(SettingsState.init(), app);
    addTearDown(settings.close);
    await settings.setRememberSubtitles(true);
    await settings.setLastSubtitle('Français');
    final player = SilentPlayerCubit(
      PlayerState(playQueue: ListQueue()),
      settings,
    );
    addTearDown(player.close);
    final mkPlayer = Player(platformPlayer: _PlatformPlayer());
    final cubit = LinuxVideoPlayerCubit(
      VideoPlayerState(
        colors: const ColorScheme.light(),
        overFlowTextColor: Colors.white,
        key: GlobalKey(),
      ),
      player,
      settings,
      mkPlayer: mkPlayer,
    );
    addTearDown(cubit.close);

    expect(cubit.getSubtitles(), isEmpty);
    final video = Video(
      videoId: 'video',
      hlsUrl: 'https://cdn.example/video.m3u8',
      captions: [Caption('Français', 'fr', route)],
    );
    final restored = mkPlayer.stream.track.firstWhere((t) => t.subtitle.data);
    cubit.switchVideo(video);
    expect((await restored).subtitle.id, cues);
    await Future<void>.delayed(Duration.zero);
    expect(requests.single.url.toString(), 'https://invidious.example$route');
    expect(requests.single.headers['authorization'], 'Basic test');
    expect(cubit.getSubtitles(), ['Off', 'Français']);
    expect(cubit.selectedSubtitle(), 1);

    await cubit.selectSubtitle(0);
    expect(mkPlayer.state.track.subtitle, SubtitleTrack.no());
    expect(cubit.selectedSubtitle(), 0);
    expect(settings.state.lastSubtitles, isEmpty);

    await cubit.selectSubtitle(1);
    expect(cubit.selectedSubtitle(), 1);
    expect(settings.state.lastSubtitles, 'Français');
  });
}
