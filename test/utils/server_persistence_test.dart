import 'dart:io';

import 'package:clipious/globals.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sembast/sembast_io.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  test('selected server survives close and reopen on file DB', () async {
    final dir = await Directory.systemTemp.createTemp('clipious_persist_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    PathProviderPlatform.instance = _FakePathProvider(dir.path);

    final dbPath = p.join(dir.path, 'clipious.db');

    var sdb = await databaseFactoryIo.openDatabase(dbPath);
    db = SembastSqfDb(sdb);
    await db.upsertServer(
      const Server(
        url: 'https://invidious.example',
        customHeaders: {'Authorization': 'Basic abc'},
      ),
    );
    expect(
      (await db.getCurrentlySelectedServer()).url,
      'https://invidious.example',
    );
    await db.close();

    sdb = await databaseFactoryIo.openDatabase(dbPath);
    db = SembastSqfDb(sdb);
    final selected = await db.getCurrentlySelectedServer();
    expect(selected.url, 'https://invidious.example');
    expect(selected.inUse, isTrue);
    expect(selected.customHeaders['Authorization'], 'Basic abc');
    await db.close();
  });

  test('serverHeadersFromJson accepts dynamic maps', () {
    final headers = serverHeadersFromJson(<dynamic, dynamic>{'A': 'B'});
    expect(headers, {'A': 'B'});
  });
}
