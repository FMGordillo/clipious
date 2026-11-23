import 'package:flutter_test/flutter_test.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';

import '../../globals.dart';

void main() {
  setUp(() async {
    db = await SembastSqfDb.createInMemory();
    // logged out: markVideoWatched must skip the server call and still save local progress
    var server = Server(url: localInvidiousServer);
    await db.upsertServer(server);
    await db.useServer(server);
  });

  test(
    'markVideoWatched sets local progress to watched when logged out',
    () async {
      const videoId = 'dQw4w9WgXcQ';
      expect(db.getVideoProgress(videoId), 0);

      await service.markVideoWatched(videoId);

      expect(db.getVideoProgress(videoId), 1);
    },
  );
}
