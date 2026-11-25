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

class MediaHandlerTestPlayer extends TestPlayerCubit {
  MediaHandlerTestPlayer(super.initialState, super.settings);

  @override
  bool get supportsMediaHandler => true;
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
}
