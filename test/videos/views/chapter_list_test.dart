import 'package:clipious/videos/models/chapter.dart';
import 'package:clipious/videos/views/components/chapter_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows each chapter time and title, tap seeks to its start', (
    tester,
  ) async {
    final chapters = [
      const Chapter(
        title: 'Intro',
        start: Duration.zero,
        end: Duration(seconds: 65),
      ),
      const Chapter(
        title: 'First topic',
        start: Duration(seconds: 65),
        end: Duration(seconds: 3750),
      ),
    ];
    Duration? seekedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChapterList(chapters: chapters, onSelect: (d) => seekedTo = d),
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('First topic'), findsOneWidget);

    await tester.tap(find.text('First topic'));
    expect(seekedTo, const Duration(seconds: 65));
  });
}
