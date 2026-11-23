import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/l10n/generated/app_localizations.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/utils/sembast_sqflite_database.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/views/tv/components/video_item.dart';

import '../../../globals.dart';

const _video = Video(videoId: 'dQw4w9WgXcQ', title: 'Test video');

Future<void> _pumpItem(WidgetTester tester, void Function() onSelect) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TvVideoItem(
          video: _video,
          autoFocus: true,
          onSelect: (_, _) => onSelect(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    db = await SembastSqfDb.createInMemory();
    var server = Server(url: localInvidiousServer);
    await db.upsertServer(server);
    await db.useServer(server);
  });

  testWidgets('short select press opens the video, not the menu', (
    tester,
  ) async {
    var selected = 0;
    await _pumpItem(tester, () => selected++);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(selected, 1);
    expect(find.text('Mark as watched'), findsNothing);
  });

  testWidgets('held select press opens the mark-as-watched menu', (
    tester,
  ) async {
    var selected = 0;
    await _pumpItem(tester, () => selected++);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    // the hold threshold is measured in real time, not fake async time
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 600)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(selected, 0);
    expect(find.text('Mark as watched'), findsOneWidget);
  });

  testWidgets('confirming the menu marks the video watched', (tester) async {
    await _pumpItem(tester, () {});

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 600)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    // the menu button is autofocused, so select confirms it
    await tester.runAsync(() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(db.getVideoProgress(_video.videoId), 1);
    expect(find.text('Mark as watched'), findsNothing);
  });
}
