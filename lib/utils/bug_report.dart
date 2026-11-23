// Builds a prefilled GitHub issue. Pure Dart so it can be unit tested.

const bugReportRepo = 'FMGordillo/clipious';

/// Max length of the encoded new-issue URL.
const maxIssueUrlLength = 7000;

const _maxTitleLength = 100;
const _truncatedNote =
    '\n\n_Report truncated to fit the GitHub link. The app keeps the full text for Copy._';

String buildIssueTitle({required String description, String? error}) {
  final prefix = error == null ? '[Bug report]' : '[Crash]';
  final firstLine = (error ?? description).trim().split('\n').first.trim();
  if (firstLine.isEmpty) return prefix;
  final shortened = firstLine.length > _maxTitleLength
      ? '${_safePrefix(firstLine, _maxTitleLength)}...'
      : firstLine;
  return '$prefix $shortened';
}

/// Full, untruncated issue body. Header lines come first so they survive truncation.
String buildIssueBody({
  required String appVersion,
  required String buildNumber,
  required String platform,
  required String description,
  String? error,
  String? stackTrace,
}) {
  final text = description.trim();
  final buffer = StringBuffer()
    ..writeln('**Version:** $appVersion (build $buildNumber)')
    ..writeln('**Platform:** $platform')
    ..writeln()
    ..writeln('**Description:**')
    ..writeln(text.isEmpty ? '(none)' : text);
  if (error != null) {
    buffer
      ..writeln()
      ..writeln('**Error:**')
      ..writeln('```')
      ..writeln(error)
      ..writeln('```');
  }
  if (stackTrace != null && stackTrace.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('**Stack trace:**')
      ..writeln('```')
      ..writeln(stackTrace)
      ..writeln('```');
  }
  return buffer.toString();
}

/// Issue URL for [title] and [body]. If the encoded URL would exceed
/// [maxIssueUrlLength], the end of [body] is cut and [truncated] is true.
({Uri url, bool truncated}) buildIssueUrl(String title, String body) {
  final urlPrefix =
      'https://github.com/$bugReportRepo/issues/new?title=${Uri.encodeComponent(title)}&body=';
  final budget = maxIssueUrlLength - urlPrefix.length;
  if (Uri.encodeComponent(body).length <= budget) {
    return (
      url: Uri.parse('$urlPrefix${Uri.encodeComponent(body)}'),
      truncated: false,
    );
  }
  // Binary search for the longest body prefix that still fits with the note.
  var low = 0;
  var high = body.length;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    final candidate = _safePrefix(body, mid) + _truncatedNote;
    if (Uri.encodeComponent(candidate).length <= budget) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  final fitted = _safePrefix(body, low) + _truncatedNote;
  return (
    url: Uri.parse('$urlPrefix${Uri.encodeComponent(fitted)}'),
    truncated: true,
  );
}

/// Prefix of [s] with [length] code units, never splitting a surrogate pair.
String _safePrefix(String s, int length) {
  var end = length;
  if (end > 0 && end < s.length && (s.codeUnitAt(end - 1) & 0xFC00) == 0xD800) {
    end--;
  }
  return s.substring(0, end);
}
