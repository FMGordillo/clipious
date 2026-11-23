import 'dart:async';

import 'package:clipious/downloads/models/downloaded_video.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/player/models/media_event.dart';
import 'package:clipious/player/states/interfaces/media_player.dart';
import 'package:clipious/player/states/linux_stream_url.dart';
import 'package:clipious/player/states/video_player.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' show VideoController;
import 'package:wakelock_plus/wakelock_plus.dart';

final _log = Logger('LinuxVideoPlayer');

class LinuxVideoPlayerCubit extends MediaPlayerCubit<VideoPlayerState> {
  final SettingsCubit settings;
  final Player mkPlayer = Player();
  late final VideoController videoController = VideoController(mkPlayer);

  StreamSubscription? _playingSub;
  StreamSubscription? _completedSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _bufferSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _widthSub;
  StreamSubscription? _heightSub;

  Duration _position = Duration.zero;
  Duration _duration = const Duration(milliseconds: 1);
  Duration _buffered = Duration.zero;
  bool _playing = false;
  double _rate = 1;
  double _aspectRatio = 16 / 9;

  LinuxVideoPlayerCubit(super.initialState, super.player, this.settings) {
    _bindStreams();
    playVideo(state.offlineVideo != null, startAt: state.startAt);
  }

  void _bindStreams() {
    _playingSub = mkPlayer.stream.playing.listen((playing) {
      _playing = playing;
      player.setEvent(
        MediaEvent(
          state: MediaState.playing,
          type: playing ? MediaEventType.play : MediaEventType.pause,
        ),
      );
      if (playing) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });
    _completedSub = mkPlayer.stream.completed.listen((done) {
      if (done) {
        player.setEvent(const MediaEvent(state: MediaState.completed));
      }
    });
    _positionSub = mkPlayer.stream.position.listen((pos) {
      _position = pos;
      EasyThrottle.throttle(
        'linux-video-progress',
        const Duration(seconds: 1),
        () {
          player.setEvent(
            MediaEvent(
              state: MediaState.playing,
              type: MediaEventType.progress,
              value: pos,
            ),
          );
        },
      );
    });
    _durationSub = mkPlayer.stream.duration.listen((d) {
      if (d > Duration.zero) {
        _duration = d;
        player.setEvent(
          MediaEvent(
            state: MediaState.ready,
            type: MediaEventType.durationChanged,
            value: d,
          ),
        );
      }
    });
    _bufferingSub = mkPlayer.stream.buffering.listen((buffering) {
      player.setEvent(
        MediaEvent(
          state: buffering ? MediaState.buffering : MediaState.playing,
        ),
      );
    });
    _bufferSub = mkPlayer.stream.buffer.listen((buf) {
      _buffered = buf;
      emit(state.copyWith(bufferPosition: buf));
    });
    _errorSub = mkPlayer.stream.error.listen((err) {
      _log.severe('media_kit error: $err');
      player.setEvent(const MediaEvent(state: MediaState.error));
    });
    _widthSub = mkPlayer.stream.width.listen((_) => _updateAspect());
    _heightSub = mkPlayer.stream.height.listen((_) => _updateAspect());
  }

  void _updateAspect() {
    final w = mkPlayer.state.width;
    final h = mkPlayer.state.height;
    if (w != null && h != null && w > 0 && h > 0) {
      _aspectRatio = w / h;
      player.setEvent(
        MediaEvent(
          state: MediaState.ready,
          type: MediaEventType.aspectRatioChanged,
          value: _aspectRatio,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    disposeControllers();
    await super.close();
  }

  @override
  void disposeControllers() {
    WakelockPlus.disable();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _bufferSub?.cancel();
    _errorSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    mkPlayer.dispose();
  }

  @override
  Future<void> playVideo(bool offline, {Duration? startAt}) async {
    if (player.state.isAudio) {
      return;
    }
    if (offline) {
      _log.warning('Offline playback is not supported on Linux desktop');
      player.setEvent(const MediaEvent(state: MediaState.error));
      return;
    }
    final video = state.video;
    if (video == null) {
      return;
    }

    player.setEvent(const MediaEvent(state: MediaState.loading));

    if (startAt == null) {
      final progress = db.getVideoProgress(video.videoId);
      if (progress > 0 && progress < 0.90) {
        startAt = Duration(
          seconds: ((video.lengthSeconds ?? 0) * progress).floor(),
        );
      }
    }

    final stream = await resolveLinuxVideoUrl(video);
    if (stream == null) {
      player.setEvent(const MediaEvent(state: MediaState.error));
      return;
    }

    _log.info('Playing ${stream.url}');
    await mkPlayer.open(
      Media(stream.url, httpHeaders: stream.headers),
      play: true,
    );
    if (startAt != null && startAt > Duration.zero) {
      await mkPlayer.seek(startAt);
    }
    if (settings.state.rememberPlayBackSpeed) {
      await mkPlayer.setRate(settings.state.lastSpeed);
      _rate = settings.state.lastSpeed;
    }
    super.playVideo(offline);
  }

  @override
  void switchVideo(Video video, {Duration? startAt}) {
    emit(state.copyWith(video: video, offlineVideo: null, startAt: startAt));
    playVideo(false, startAt: startAt);
  }

  @override
  void switchToOfflineVideo(DownloadedVideo v) {
    emit(state.copyWith(offlineVideo: v, video: null));
    playVideo(true);
  }

  @override
  void togglePlaying() {
    if (_playing) {
      pause();
    } else {
      play();
    }
  }

  @override
  void toggleControls(bool visible) {
    emit(state.copyWith(disableControls: !visible));
  }

  @override
  double getAspectRatio() => _aspectRatio;

  @override
  bool isPlaying() => _playing;

  @override
  void play() => mkPlayer.play();

  @override
  void pause() => mkPlayer.pause();

  @override
  void seek(Duration position) => mkPlayer.seek(position);

  @override
  Duration position() => _position;

  @override
  Duration? bufferedPosition() => _buffered;

  @override
  double? speed() => _rate;

  @override
  List<String> getVideoTracks() => [];

  @override
  List<String> getAudioTracks() => [];

  @override
  List<String> getSubtitles() => [];

  @override
  int selectedVideoTrack() => -1;

  @override
  int selectedAudioTrack() => -1;

  @override
  int selectedSubtitle() => -1;

  @override
  void selectVideoTrack(int index) {}

  @override
  void selectAudioTrack(int index) {}

  @override
  void selectSubtitle(int index) {}

  @override
  bool isMuted() => mkPlayer.state.volume == 0;

  @override
  void toggleVolume(bool soundOn) {
    mkPlayer.setVolume(soundOn ? 100 : 0);
  }

  @override
  void setSpeed(double d) {
    _rate = d;
    mkPlayer.setRate(d);
    settings.setLastSpeed(d);
  }

  @override
  double getSpeed() => _rate;

  @override
  bool hasDashToggle() => false;

  @override
  bool isUsingDash() => false;

  @override
  void toggleDash() {}

  @override
  Duration duration() =>
      _duration > Duration.zero ? _duration : const Duration(milliseconds: 1);
}
