/// A video chapter, derived from timestamp lines in the video description.
class Chapter {
  const Chapter({required this.title, required this.start, required this.end});

  final String title;
  final Duration start;
  final Duration end;
}

// Mirrors YouTube's rules: first chapter at 0:00, at least 3 chapters,
// ascending, each at least 10s. Anything else yields no chapters.
const _minChapters = 3;
const _minChapterLength = Duration(seconds: 10);

final _lineBreak = RegExp(r'<br\s*/?>|\n', caseSensitive: false);
final _tag = RegExp(r'<[^>]*>');
final _timestamp = RegExp(r'^(?:(\d+):)?([0-5]?\d):([0-5]\d)\s*(.*)$');

// &amp; must be last so `&amp;lt;` stays `&lt;`.
String _decode(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

Chapter? chapterAt(List<Chapter> chapters, Duration position) {
  for (final chapter in chapters) {
    if (position < chapter.end) return chapter;
  }
  return null;
}

List<Chapter> parseChapters(String descriptionHtml, int lengthSeconds) {
  final stamps = <(Duration, String)>[];
  for (final line in descriptionHtml.split(_lineBreak)) {
    // Invidious wraps timestamps in <a> links, so match on the text only.
    final text = _decode(line.replaceAll(_tag, '').trim());
    final m = _timestamp.firstMatch(text);
    if (m == null) continue;
    stamps.add((
      Duration(
        hours: int.parse(m[1] ?? '0'),
        minutes: int.parse(m[2]!),
        seconds: int.parse(m[3]!),
      ),
      m[4]!.trim(),
    ));
  }

  if (stamps.length < _minChapters || stamps.first.$1 != Duration.zero) {
    return [];
  }

  final total = Duration(seconds: lengthSeconds);
  final chapters = <Chapter>[];
  for (var i = 0; i < stamps.length; i++) {
    final start = stamps[i].$1;
    final end = i + 1 < stamps.length ? stamps[i + 1].$1 : total;
    if (end - start < _minChapterLength) return [];
    chapters.add(Chapter(title: stamps[i].$2, start: start, end: end));
  }
  return chapters;
}
