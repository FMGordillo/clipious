import 'package:clipious/app/states/app.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/home/models/db/home_layout.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/settings/states/server_list_settings.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_app_cubit.dart';

void main() {
  late AppCubit app;
  setUp(() async {
    db = await SembastSqfDb.createInMemory();
    app = TestAppCubit(AppState(0, null, HomeLayout()));
    await app.initState();
  });

  tearDown(() async => await db.close());

  test('adding own server selects it when first', () async {
    final servers = ServerListSettingsCubit(
      const ServerListSettingsState(dbServers: [], publicServers: []),
      app,
    );
    await servers.refreshServers();
    expect(servers.state.publicServers, isEmpty);

    await servers.saveServer(const Server(url: 'https://invidious.example'));
    expect(servers.state.dbServers.length, 1);
    expect(servers.isLoggedInToServer('https://invidious.example'), false);

    final inUse = await db.getCurrentlySelectedServer();
    expect(inUse.url, 'https://invidious.example');
    expect(app.state.server?.url, 'https://invidious.example');
  });

  test('switching server', () async {
    final servers = ServerListSettingsCubit(
      const ServerListSettingsState(dbServers: [], publicServers: []),
      app,
    );
    await servers.refreshServers();

    const s1 = Server(url: 'https://a.example');
    const s2 = Server(url: 'https://b.example');
    await servers.upsertServer(s1);
    await servers.upsertServer(s2);

    expect(servers.state.dbServers.length, 2);

    await servers.switchServer(s1);
    var inUse = await db.getCurrentlySelectedServer();
    expect(inUse.url, s1.url);
    var inUseCount = servers.state.dbServers
        .where((element) => element.inUse == true)
        .length;
    expect(inUseCount, 1);
    expect(app.state.server?.url, s1.url);

    await servers.switchServer(s2);
    inUse = await db.getCurrentlySelectedServer();
    expect(inUse.url, s2.url);
    inUseCount = servers.state.dbServers
        .where((element) => element.inUse == true)
        .length;
    expect(inUseCount, 1);
    expect(app.state.server?.url, s2.url);
  });
}
