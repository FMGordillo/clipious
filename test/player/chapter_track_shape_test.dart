import 'package:clipious/player/views/components/chapter_track_shape.dart';
import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slider with chapter ticks paints and reports the value', (
    tester,
  ) async {
    final chapters = [
      const Chapter(
        title: 'A',
        start: Duration.zero,
        end: Duration(seconds: 30),
      ),
      const Chapter(
        title: 'B',
        start: Duration(seconds: 30),
        end: Duration(seconds: 60),
      ),
    ];
    double value = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: ChapterTrackShape(
                  chapters: chapters,
                  total: const Duration(seconds: 60),
                ),
              ),
              child: Slider(
                min: 0,
                max: 60000,
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(value, greaterThan(0));
  });
}
