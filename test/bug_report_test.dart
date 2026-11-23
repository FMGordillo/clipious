import 'package:clipious/utils/bug_report.dart';
import 'package:flutter_test/flutter_test.dart';

String _body({String? stack, String description = 'Button does nothing'}) =>
    buildIssueBody(
      appVersion: '2.2.0',
      buildNumber: '10',
      platform: 'android 14',
      description: description,
      error: stack == null ? null : 'StateError: boom',
      stackTrace: stack,
    );

void main() {
  test('huge stack trace is truncated so the URL stays under the limit', () {
    final hugeStack = List.generate(
      5000,
      (i) => '#$i package:clipious/some/file.dart:$i:1 ünïcödé 🔥',
    ).join('\n');
    final issue = buildIssueUrl(
      buildIssueTitle(description: '', error: 'StateError: boom'),
      _body(stack: hugeStack),
    );

    expect(issue.truncated, isTrue);
    expect(issue.url.toString().length, lessThanOrEqualTo(maxIssueUrlLength));
    // header survives truncation, note tells the user it was cut
    expect(issue.url.queryParameters['body'], startsWith('**Version:** 2.2.0'));
    expect(issue.url.queryParameters['body'], contains('truncated'));
  });

  test('small report is sent unchanged', () {
    final text = _body(stack: 'frame 1\nframe 2');
    final issue = buildIssueUrl('[Crash] StateError: boom', text);

    expect(issue.truncated, isFalse);
    expect(issue.url.queryParameters['body'], text);
  });

  test('URL targets FMGordillo/clipious', () {
    final issue = buildIssueUrl('[Bug report] x', _body());

    expect(issue.url.host, 'github.com');
    expect(issue.url.path, '/FMGordillo/clipious/issues/new');
  });

  test('body includes version and platform lines', () {
    final text = _body();

    expect(text, contains('**Version:** 2.2.0 (build 10)'));
    expect(text, contains('**Platform:** android 14'));
  });
}
