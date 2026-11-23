import 'package:clipious/utils.dart';
import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter/material.dart';

class ChapterList extends StatelessWidget {
  final List<Chapter> chapters;
  final void Function(Duration) onSelect;

  const ChapterList({
    super.key,
    required this.chapters,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final chapter in chapters)
          InkWell(
            onTap: () => onSelect(chapter.start),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Text(prettyDurationCustom(chapter.start)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(chapter.title)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
