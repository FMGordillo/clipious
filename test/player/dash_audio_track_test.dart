import 'package:flutter_test/flutter_test.dart';
import 'package:clipious/player/models/dash_audio_track.dart';

const _manifest = '''
<?xml version="1.0" encoding="UTF-8"?>
<MPD>
 <Period>
  <AdaptationSet id="0" mimeType="audio/mp4" label="Hindi [64k]" lang="hi">
   <Role schemeIdUri="urn:mpeg:dash:role:2011" value="alternate"/>
   <Representation id="139" bandwidth="64000">
    <BaseURL>https://example.com/hi-low</BaseURL>
   </Representation>
  </AdaptationSet>
  <AdaptationSet id="1" mimeType="audio/mp4" label="Hindi [128k]" lang="hi">
   <Role schemeIdUri="urn:mpeg:dash:role:2011" value="alternate"/>
   <Representation id="140" bandwidth="128000">
    <BaseURL>https://example.com/hi-high</BaseURL>
   </Representation>
  </AdaptationSet>
  <AdaptationSet id="2" mimeType="audio/mp4" label="English original [129k]" lang="en">
   <Role schemeIdUri="urn:mpeg:dash:role:2011" value="main"/>
   <Representation id="141" bandwidth="129000">
    <BaseURL>https://example.com/en</BaseURL>
   </Representation>
  </AdaptationSet>
  <AdaptationSet id="3" mimeType="video/mp4" label="ignore">
   <Representation id="137" bandwidth="5000000">
    <BaseURL>https://example.com/video</BaseURL>
   </Representation>
  </AdaptationSet>
 </Period>
</MPD>
''';

void main() {
  test('parseDashAudioTracks keeps best bitrate per lang, default first', () {
    final tracks = parseDashAudioTracks(_manifest);

    expect(tracks.length, 2);
    expect(tracks[0].lang, 'en');
    expect(tracks[0].isDefault, true);
    expect(tracks[0].label, 'English original');
    expect(tracks[0].url, 'https://example.com/en');

    expect(tracks[1].lang, 'hi');
    expect(tracks[1].isDefault, false);
    expect(tracks[1].label, 'Hindi');
    expect(tracks[1].url, 'https://example.com/hi-high');
  });
}
