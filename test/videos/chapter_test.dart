import 'package:clipious/videos/models/chapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timestamp links become chapters ending at the next start', () {
    const html =
        '<a href="/watch?v=abc&amp;t=0">0:00</a> Intro<br />'
        '<a href="/watch?v=abc&amp;t=65">1:05</a> First topic<br />'
        '<a href="/watch?v=abc&amp;t=3750">1:02:30</a> Wrap-up';

    final chapters = parseChapters(html, 3800);

    expect(chapters.map((c) => c.title), ['Intro', 'First topic', 'Wrap-up']);
    expect(chapters.map((c) => c.start), [
      Duration.zero,
      const Duration(seconds: 65),
      const Duration(seconds: 3750),
    ]);
    expect(chapters.map((c) => c.end), [
      const Duration(seconds: 65),
      const Duration(seconds: 3750),
      const Duration(seconds: 3800),
    ]);
  });

  test('plain text lines and HTML entities in titles are decoded', () {
    const html =
        '0:00 Q&amp;A\n0:30 Demo &lt;b&gt;\n1:00 End &quot;x&quot; &#39;y&#39;';

    final chapters = parseChapters(html, 90);

    expect(chapters.map((c) => c.title), ['Q&A', 'Demo <b>', 'End "x" \'y\'']);
  });

  test('returns no chapters when the first timestamp is not 0:00', () {
    const html = '0:05 Intro<br />0:30 Middle<br />1:00 End';

    expect(parseChapters(html, 120), isEmpty);
  });

  test('returns no chapters when there are fewer than 3', () {
    const html = '0:00 Intro<br />0:30 Middle';

    expect(parseChapters(html, 120), isEmpty);
  });

  test('returns no chapters when a chapter is shorter than 10s', () {
    const html = '0:00 Intro<br />0:05 Short<br />1:00 End';

    expect(parseChapters(html, 120), isEmpty);
  });

  test('returns no chapters when timestamps are out of order', () {
    const html = '0:00 Intro<br />1:00 Middle<br />0:30 End';

    expect(parseChapters(html, 120), isEmpty);
  });

  test('returns no chapters when the last chapter is past the video end', () {
    const html = '0:00 Intro<br />0:30 Middle<br />1:00 End';

    expect(parseChapters(html, 55), isEmpty);
  });

  test('chapterAt returns the chapter containing the position', () {
    final chapters = parseChapters('0:00 A<br />0:30 B<br />1:00 C', 90);

    expect(chapterAt(chapters, Duration.zero)?.title, 'A');
    expect(chapterAt(chapters, const Duration(seconds: 29))?.title, 'A');
    expect(chapterAt(chapters, const Duration(seconds: 30))?.title, 'B');
    expect(chapterAt(chapters, const Duration(seconds: 89))?.title, 'C');
    expect(chapterAt([], const Duration(seconds: 5)), isNull);
  });
}
