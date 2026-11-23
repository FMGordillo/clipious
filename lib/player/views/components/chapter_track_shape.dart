import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter/material.dart';

/// Slider track that also draws a tick at the start of each chapter.
class ChapterTrackShape extends RoundedRectSliderTrackShape {
  ChapterTrackShape({required this.chapters, required this.total});

  final List<Chapter> chapters;
  final Duration total;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    if (total.inMilliseconds <= 0) return;

    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final paint = Paint()..color = Colors.white70;
    // The first chapter starts at 0:00, so its tick would sit on the edge.
    for (final chapter in chapters.skip(1)) {
      final fraction = chapter.start.inMilliseconds / total.inMilliseconds;
      final x = rect.left + rect.width * fraction;
      context.canvas.drawRect(
        Rect.fromLTWH(x - 1, rect.top, 2, rect.height),
        paint,
      );
    }
  }
}
