import 'package:clipious/downloads/models/downloaded_video.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/player/states/audio_player.dart';
import 'package:clipious/player/states/interfaces/media_player.dart';
import 'package:clipious/player/states/linux_audio_player.dart';
import 'package:clipious/player/states/player.dart';
import 'package:clipious/player/views/components/player_controls.dart';
import 'package:clipious/settings/states/settings.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:clipious/videos/views/components/offline_video_thumbnail.dart';
import 'package:clipious/videos/views/components/video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AudioPlayer extends StatelessWidget {
  final Video? video;
  final DownloadedVideo? offlineVideo;
  final bool miniPlayer;

  const AudioPlayer({
    super.key,
    this.video,
    required this.miniPlayer,
    this.offlineVideo,
  }) : assert(
         video == null || offlineVideo == null,
         'cannot provide both video and offline video\n',
       );

  @override
  Widget build(BuildContext context) {
    var player = context.read<PlayerCubit>();
    var settings = context.read<SettingsCubit>();
    final initial = AudioPlayerState(offlineVideo: offlineVideo, video: video);

    if (isLinuxDesktop) {
      return BlocProvider(
        create: (context) => LinuxAudioPlayerCubit(initial, player, settings),
        child: BlocBuilder<LinuxAudioPlayerCubit, AudioPlayerState>(
          builder: (context, playerState) =>
              BlocListener<PlayerCubit, PlayerState>(
                listenWhen: (previous, current) =>
                    previous.mediaCommand != current.mediaCommand &&
                    current.mediaCommand != null,
                listener: (context, state) => context
                    .read<LinuxAudioPlayerCubit>()
                    .handleCommand(state.mediaCommand!),
                child: _AudioShell(
                  miniPlayer: miniPlayer,
                  playerState: playerState,
                  mediaPlayerCubit: context.read<LinuxAudioPlayerCubit>(),
                ),
              ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => AudioPlayerCubit(initial, player, settings),
      child: BlocBuilder<AudioPlayerCubit, AudioPlayerState>(
        builder: (context, playerState) =>
            BlocListener<PlayerCubit, PlayerState>(
              listenWhen: (previous, current) =>
                  previous.mediaCommand != current.mediaCommand &&
                  current.mediaCommand != null,
              listener: (context, state) => context
                  .read<AudioPlayerCubit>()
                  .handleCommand(state.mediaCommand!),
              child: _AudioShell(
                miniPlayer: miniPlayer,
                playerState: playerState,
                mediaPlayerCubit: context.read<AudioPlayerCubit>(),
              ),
            ),
      ),
    );
  }
}

class _AudioShell extends StatelessWidget {
  final bool miniPlayer;
  final AudioPlayerState playerState;
  final MediaPlayerCubit mediaPlayerCubit;

  const _AudioShell({
    required this.miniPlayer,
    required this.playerState,
    required this.mediaPlayerCubit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(miniPlayer ? 8 : 0.0),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          playerState.video != null
              ? VideoThumbnailView(
                  decoration: const BoxDecoration(),
                  videoId: playerState.video!.videoId,
                  thumbnails: playerState.video?.thumbnails ?? [],
                )
              : playerState.offlineVideo != null
              ? OfflineVideoThumbnail(
                  borderRadius: 0,
                  key: ValueKey(playerState.offlineVideo?.videoId ?? ''),
                  video: playerState.offlineVideo!,
                )
              : const SizedBox.shrink(),
          PlayerControls(mediaPlayerCubit: mediaPlayerCubit),
        ],
      ),
    );
  }
}
