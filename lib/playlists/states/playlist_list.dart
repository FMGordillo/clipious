import 'package:bloc/bloc.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:clipious/utils/models/paginated_list.dart';
import 'package:logging/logging.dart';

import '../models/playlist.dart';

part 'playlist_list.freezed.dart';

const couldNotGetPlaylits = 'could-not-get-playlists';
final _log = Logger('PlaylistListCubit');

class PlaylistListCubit extends Cubit<PlaylistListState> {
  ScrollController scrollController = ScrollController();
  PlaylistListCubit(super.initialState) {
    onReady();
  }

  void onReady() {
    scrollController.addListener(onScrollEvent);
    getPlaylists();
  }

  onScrollEvent() {
    if (state.paginatedList.getHasMore()) {
      if (scrollController.hasClients) {
        if (scrollController.position.maxScrollExtent * 0.9 ==
            scrollController.offset) {
          EasyDebounce.debounce(
            'get-more-playlists',
            const Duration(milliseconds: 500),
            getMorePlaylists,
          );
        }
      }
    }
  }

  getMorePlaylists() async {
    if (!state.loading && state.paginatedList.getHasMore()) {
      loadPlaylist(() async {
        List<Playlist> playlists = await state.paginatedList.getMoreItems();
        List<Playlist> currentPlaylists = state.playlists;
        currentPlaylists.addAll(playlists);
        return currentPlaylists;
      });
    }
  }

  refreshPlaylists() async {
    loadPlaylist(state.paginatedList.refresh);
  }

  getPlaylists() async {
    loadPlaylist(state.paginatedList.getItems);
  }

  loadPlaylist(Future<List<Playlist>> Function() refreshFunction) async {
    emit(state.copyWith(error: '', loading: true));
    try {
      var playlists = await refreshFunction();
      if (!isClosed) {
        emit(state.copyWith(playlists: playlists, loading: false));
      }
    } catch (err, stackTrace) {
      _log.severe('Could not fetch playlists', err, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            error: couldNotGetPlaylits,
            playlists: [],
            loading: false,
          ),
        );
      }
    }
  }

  @override
  close() async {
    scrollController.dispose();
    super.close();
  }
}

@freezed
sealed class PlaylistListState with _$PlaylistListState {
  const factory PlaylistListState({
    required PaginatedList<Playlist> paginatedList,
    @Default([]) List<Playlist> playlists,
    @Default(true) bool loading,
    @Default('') String error,
  }) = _PlaylistListState;
}
