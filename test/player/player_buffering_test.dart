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

void main() {
  testWidgets('playback stays buffering until the backend ends it', (
    tester,
  ) async {
    db = await SembastSqfDb.createInMemory();
    final app = TestAppCubit(AppState(0, null, HomeLayout()));
    final settings = TestSettingsCubit(SettingsState.init(), app);
    final player = TestPlayerCubit(PlayerState.init(null), settings);
    addTearDown(app.close);
    addTearDown(settings.close);
    addTearDown(player.close);

    expect(player.state.isBuffering, isFalse);
    const buffering = MediaEvent(state: MediaState.buffering);
    player.setEvent(buffering);
    expect(player.state.isBuffering, isTrue);

    for (final type in [
      MediaEventType.sponsorSkipped,
      MediaEventType.seek,
      MediaEventType.progress,
      MediaEventType.bufferChanged,
    ]) {
      player.setEvent(
        MediaEvent(
          state: MediaState.playing,
          type: type,
          value: const Duration(seconds: 10),
        ),
      );
      expect(player.state.isBuffering, isTrue);
    }

    player.setEvent(
      const MediaEvent(
        state: MediaState.playing,
        type: MediaEventType.bufferingEnd,
      ),
    );
    expect(player.state.isBuffering, isFalse);

    player.setEvent(buffering);
    player.setEvent(const MediaEvent(state: MediaState.error));
    expect(player.state.isBuffering, isFalse);
    await tester.pump();
  });
}
