import 'package:bloc/bloc.dart';
import 'package:clipious/videos/models/video.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/comments/models/video_comments.dart';

import '../../globals.dart';
import '../../settings/models/errors/invidious_service_error.dart';

part 'comments.freezed.dart';

class CommentsCubit extends Cubit<CommentsState> {
  CommentsCubit(super.initialState) {
    onReady();
  }

  onReady() {
    getComments();
  }

  loadMore() async {
    final videoId = state.video.videoId;
    final continuation = state.continuation;

    emit(state.copyWith(loadingComments: true));

    VideoComments comments =
        await service.getComments(videoId, continuation: continuation);

    if (isClosed) return;
    var stateComments = state.comments;
    stateComments.comments.addAll(comments.comments);
    emit(state.copyWith(
        comments: stateComments,
        continuation: comments.continuation,
        loadingComments: false));
  }

  getComments() async {
    final videoId = state.video.videoId;
    final sortBy = state.sortBy;
    final source = state.source;

    emit(state.copyWith(
        error: '',
        loadingComments: true,
        comments: VideoComments(0, videoId, '', [])));

    try {
      VideoComments comments =
          await service.getComments(videoId, sortBy: sortBy, source: source);
      if (isClosed) return;
      emit(state.copyWith(
          comments: comments,
          loadingComments: false,
          continuation: comments.continuation));
    } catch (err) {
      if (isClosed) return;
      if (err is InvidiousServiceError) {
        emit(state.copyWith(error: err.message));
      } else {
        emit(state.copyWith(error: err.toString()));
        rethrow;
      }
    }
  }
}

@freezed
sealed class CommentsState with _$CommentsState {
  const factory CommentsState(
      {required Video video,
      @Default(true) bool loadingComments,
      String? continuation,
      @Default(false) bool continuationLoaded,
      required VideoComments comments,
      @Default('') String error,
      String? source,
      String? sortBy}) = _CommentsState;

  static CommentsState init(
      {required Video video,
      bool? loadingComments,
      String? continuation,
      bool? continuationLoaded,
      String? error,
      String? source,
      String? sortBy}) {
    var comments = VideoComments(0, video.videoId, continuation, []);

    return CommentsState(
        video: video,
        comments: comments,
        loadingComments: loadingComments ?? true,
        continuation: continuation,
        continuationLoaded: continuationLoaded ?? false,
        error: error ?? '',
        source: source,
        sortBy: sortBy);
  }
}
