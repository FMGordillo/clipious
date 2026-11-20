/// One selectable audio language from an Invidious DASH manifest.
class DashAudioTrack {
  final String label;
  final String lang;
  final String url;
  final String? itag;
  final int bandwidth;
  final bool isDefault;

  const DashAudioTrack({
    required this.label,
    required this.lang,
    required this.url,
    this.itag,
    required this.bandwidth,
    required this.isDefault,
  });

  DashAudioTrack copyWith({
    String? label,
    String? lang,
    String? url,
    String? itag,
    int? bandwidth,
    bool? isDefault,
  }) {
    return DashAudioTrack(
      label: label ?? this.label,
      lang: lang ?? this.lang,
      url: url ?? this.url,
      itag: itag ?? this.itag,
      bandwidth: bandwidth ?? this.bandwidth,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

final _adaptationSet = RegExp(
  r'<AdaptationSet\b([^>]*)>(.*?)</AdaptationSet>',
  caseSensitive: false,
  dotAll: true,
);
final _attr = RegExp(r'''(\w+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
final _bandwidth = RegExp(r'bandwidth="(\d+)"', caseSensitive: false);
final _representationId = RegExp(
  r'<Representation\b[^>]*\bid="([^"]+)"',
  caseSensitive: false,
);
final _baseUrl = RegExp(
  r'<BaseURL>\s*([^<]+?)\s*</BaseURL>',
  caseSensitive: false,
);
final _roleMain = RegExp(r'value="main"', caseSensitive: false);
final _bitrateSuffix = RegExp(r' \[\d+k\]$', caseSensitive: false);

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

    final lang = attrs['lang'] ?? 'und';
    raw.add(
      DashAudioTrack(
        label: _displayLabel(attrs['label'], lang),
        lang: lang,
        url: url,
        itag: _representationId.firstMatch(body)?.group(1),
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
    return best.copyWith(isDefault: group.any((t) => t.isDefault));
  }).toList();

  tracks.sort((a, b) {
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.label.compareTo(b.label);
  });
  return tracks;
}

/// True when the user has more than one real language to pick from.
bool hasSelectableAudioLanguages(List<DashAudioTrack> tracks) {
  if (tracks.length <= 1) return false;
  final langs = tracks.map((t) => t.lang).where((l) => l != 'und').toSet();
  if (langs.length > 1) return true;
  final labels = tracks
      .map((t) => t.label.toLowerCase())
      .where((l) => l != 'unknown' && l.isNotEmpty)
      .toSet();
  return labels.length > 1;
}

String _displayLabel(String? rawLabel, String lang) {
  var label = (rawLabel ?? 'Unknown').replaceFirst(_bitrateSuffix, '');
  if (label.toLowerCase() == 'unknown' && lang != 'und') return lang;
  return label;
}

Map<String, String> _parseAttrs(String attrs) {
  final out = <String, String>{};
  for (final m in _attr.allMatches(attrs)) {
    out[m.group(1)!] = m.group(2) ?? m.group(3) ?? '';
  }
  return out;
}
