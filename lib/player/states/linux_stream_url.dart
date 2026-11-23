import 'package:clipious/globals.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/videos/models/video.dart';

final _googleCdnRegex = RegExp(r'https://(.+)googlevideo.com/');

typedef LinuxStream = ({String url, Map<String, String>? headers});

/// shortcut: prefer HLS / progressive over DASH for media_kit; add track UI later if needed.
Future<LinuxStream?> resolveLinuxVideoUrl(Video video) async {
  final server = await db.getCurrentlySelectedServer();
  final useProxy = service.useProxy();

  if (video.hlsUrl != null) {
    return _absolute(
      video.hlsUrl!,
      server,
      useProxy: useProxy,
      appendLocal: true,
    );
  }

  final streams = video.formatStreams;
  if (streams != null && streams.isNotEmpty) {
    var url = streams.last.url;
    if (!url.startsWith('http')) {
      url = '${server.url}$url';
    }
    if (useProxy) {
      url = url.replaceFirst(_googleCdnRegex, '${server.url}/');
    }
    return (url: url, headers: server.headersForUrl(url));
  }

  if (video.dashUrl != null) {
    return _absolute(
      video.dashUrl!,
      server,
      useProxy: useProxy,
      appendLocal: true,
    );
  }

  return null;
}

Future<LinuxStream?> resolveLinuxAudioUrl(Video video) async {
  final server = await db.getCurrentlySelectedServer();
  final useProxy = service.useProxy();

  final audio = video.adaptiveFormats
      ?.where((e) => e.type.contains('audio'))
      .firstOrNull;
  if (audio != null) {
    var url = audio.url;
    if (!url.startsWith('http')) {
      url = '${server.url}$url';
    }
    if (useProxy) {
      url = url.replaceFirst(_googleCdnRegex, '${server.url}/');
    }
    return (url: url, headers: server.headersForUrl(url));
  }

  // Fall back to progressive muxed stream (includes audio).
  return resolveLinuxVideoUrl(video);
}

LinuxStream _absolute(
  String raw,
  Server server, {
  required bool useProxy,
  bool appendLocal = false,
}) {
  var url = raw;
  if (appendLocal && useProxy) {
    url += url.contains('?') ? '&local=true' : '?local=true';
  }
  if (!url.startsWith('http')) {
    url = '${server.url}$url';
  }
  return (url: url, headers: server.headersForUrl(url));
}
