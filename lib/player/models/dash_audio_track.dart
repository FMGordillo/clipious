/// One selectable audio language from an Invidious DASH manifest.
class DashAudioTrack {
  final String label;
  final String lang;
  final String url;
  final int bandwidth;
  final bool isDefault;

  const DashAudioTrack({
    required this.label,
    required this.lang,
    required this.url,
    required this.bandwidth,
    required this.isDefault,
  });
}

final _adaptationSet = RegExp(
  r'<AdaptationSet\b([^>]*)>(.*?)</AdaptationSet>',
  caseSensitive: false,
  dotAll: true,
);
final _attr = RegExp(r'''(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
final _bandwidth = RegExp(r'bandwidth="(\d+)"', caseSensitive: false);
final _baseUrl = RegExp(
  r'<BaseURL>\s*([^<]+?)\s*</BaseURL>',
  caseSensitive: false,
);
final _roleMain = RegExp(r'value="main"', caseSensitive: false);
final _bitrateSuffix = RegExp(r' \[\d+k\]$');

/// Parses audio AdaptationSets, keeps best bitrate per language, default first.
List<DashAudioTrack> parseDashAudioTracks(String manifest) {
  final raw = <DashAudioTrack>[];

  for (final match in _adaptationSet.allMatches(manifest)) {
    final attrs = _parseAttrs(match.group(1)!);
    final mime = attrs['mimeType'] ?? '';
    if (!mime.startsWith('audio')) continue;

    final body = match.group(2)!;
    final url = _baseUrl.firstMatch(body)?.group(1)?.trim();
    if (url == null || url.isEmpty) continue;

    final label = attrs['label'] ?? 'Unknown';
    raw.add(
      DashAudioTrack(
        label: label.replaceFirst(_bitrateSuffix, ''),
        lang: attrs['lang'] ?? 'und',
        url: url,
        bandwidth:
            int.tryParse(_bandwidth.firstMatch(body)?.group(1) ?? '') ?? 0,
        isDefault: _roleMain.hasMatch(body),
      ),
    );
  }

  final byKey = <String, List<DashAudioTrack>>{};
  for (final track in raw) {
    final key = track.lang != 'und' ? track.lang : track.label;
    byKey.putIfAbsent(key, () => []).add(track);
  }

  final tracks = byKey.values.map((group) {
    group.sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    final best = group.first;
    return DashAudioTrack(
      label: best.label,
      lang: best.lang,
      url: best.url,
      bandwidth: best.bandwidth,
      isDefault: group.any((t) => t.isDefault),
    );
  }).toList();

  tracks.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.label.compareTo(b.label);
  });
  return tracks;
}

Map<String, String> _parseAttrs(String attrs) {
  final out = <String, String>{};
  for (final m in _attr.allMatches(attrs)) {
    out[m.group(1)!] = m.group(2) ?? m.group(3) ?? '';
  }
  return out;
}
