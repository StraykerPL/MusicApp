import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Models/music_file.dart';

final class PlaylistViewModel extends ChangeNotifier {
  static const String allFilesPlaylistName = 'All Files';

  PlaylistViewModel({
    required PlaylistManager playlistManager,
    required SoundCollectionManager soundCollectionManager,
  })  : _playlistManager = playlistManager,
        _soundCollectionManager = soundCollectionManager;

  final PlaylistManager _playlistManager;
  final SoundCollectionManager _soundCollectionManager;

  StreamSubscription<PlaybackState>? _playbackSubscription;
  MusicFile? _currentSong;
  bool _isSearchVisible = false;
  bool _isLoopModeOn = false;
  bool _isPlaybackAvailable = true;
  String _searchQuery = '';
  bool _initialized = false;
  bool _disposed = false;

  String get currentPlaylistName => _playlistManager.currentPlaylist;
  UnmodifiableListView<String> get availablePlaylists =>
      UnmodifiableListView(_playlistManager.availablePlaylists);
  UnmodifiableListView<MusicFile> get songs =>
      UnmodifiableListView(_playlistManager.currentPlaylistSongs);
  UnmodifiableListView<MusicFile> get displayedSongs => UnmodifiableListView(
        _playlistManager.currentPlaylistSongs.where(
          (song) =>
              song.name.toUpperCase().contains(_searchQuery.toUpperCase()),
        ),
      );
  MusicFile? get currentSong => _currentSong;
  Stream<bool> get playingStream => _soundCollectionManager.playingStream;
  bool get isSearchVisible => _isSearchVisible;
  bool get isLoopModeOn => _isLoopModeOn;
  String get searchQuery => _searchQuery;
  bool get isPlaybackAvailable => _isPlaybackAvailable;
  bool get canControlCurrentSong =>
      _isPlaybackAvailable &&
      _currentSong != null &&
      songs.contains(_currentSong);
  bool get canShuffle => _isPlaybackAvailable && songs.isNotEmpty;
  bool get canRemoveSongs => currentPlaylistName != allFilesPlaylistName;
  bool get showsLoopControl => currentPlaylistName != allFilesPlaylistName;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _playlistManager.addListener(_onPlaylistChanged);
    _playbackSubscription =
        _soundCollectionManager.getPlaybackStateSubscription;
    _playbackSubscription!.onData(_onPlaybackStateChanged);
    _soundCollectionManager.setNotificationSkipHandlers(
      skipToNext: playNextSongFromNotification,
      skipToPrevious: playPreviousSongFromNotification,
    );

    await _soundCollectionManager.setLoopMode(true);
    await _playlistManager.loadAvailablePlaylists();
    _notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    _notifyListeners();
  }

  void toggleSearch() {
    _searchQuery = '';
    _isSearchVisible = !_isSearchVisible;
    _notifyListeners();
  }

  Future<void> selectSong(MusicFile song) async {
    if (!_isPlaybackAvailable || !songs.contains(song)) {
      return;
    }

    _currentSong = song;
    _notifyListeners();
    await _soundCollectionManager.selectAndPlaySong(song);
  }

  Future<void> shuffle() async {
    if (!_isPlaybackAvailable) {
      return;
    }

    final song = await _soundCollectionManager.getRandomMusic(
      _playlistManager.currentPlaylistSongs,
    );

    if (song == null || _disposed || !_isPlaybackAvailable) {
      return;
    }

    _currentSong = song;
    _notifyListeners();

    await _soundCollectionManager.selectAndPlaySong(song);
  }

  Future<void> resumeOrPause() async {
    if (!canControlCurrentSong) {
      return;
    }

    await _soundCollectionManager.resumeOrPauseSong();
  }

  Future<void> toggleLoopMode() async {
    if (!_isPlaybackAvailable) {
      return;
    }

    _isLoopModeOn = !_isLoopModeOn;
    _notifyListeners();
    await _soundCollectionManager.setLoopMode(_isLoopModeOn);
  }

  Future<void> switchPlaylist(String name) async {
    await _stopAndResetPlayback();

    try {
      await _playlistManager.switchToPlaylist(name);
    } finally {
      _isPlaybackAvailable = true;
      _applyLoopModeForCurrentPlaylist();
      _notifyListeners();
    }
  }

  Future<void> enterSettings() async {
    await _stopAndResetPlayback();
  }

  void leaveSettings() {
    if (_disposed) {
      return;
    }

    _isPlaybackAvailable = true;
    _applyLoopModeForCurrentPlaylist();
    _notifyListeners();
  }

  Future<List<String>> getNamedPlaylistNames() async {
    final playlists = await _playlistManager.getPlaylists();
    return playlists.map((playlist) => playlist.name).toList();
  }

  Future<void> addSongToPlaylist(
    String playlistName,
    MusicFile song,
  ) async {
    await _playlistManager.addSongToPlaylistByName(
      playlistName,
      song.filePath,
    );
  }

  Future<bool> removeSongFromCurrentPlaylist(MusicFile song) async {
    if (!canRemoveSongs) {
      return false;
    }

    await _playlistManager.removeSongFromPlaylistByName(
      currentPlaylistName,
      song.filePath,
    );
    return true;
  }

  Future<void> playNextSongFromNotification() async {
    final currentSong = _currentSong;
    if (!_isPlaybackAvailable ||
        currentSong == null ||
        !songs.contains(currentSong) ||
        songs.isEmpty ||
        _disposed) {
      return;
    }

    await _playSongFromNotification(
      _playlistManager.getNextSongFromPlaylist(currentSong),
    );
  }

  Future<void> playPreviousSongFromNotification() async {
    final currentSong = _currentSong;
    if (!_isPlaybackAvailable ||
        currentSong == null ||
        !songs.contains(currentSong) ||
        songs.isEmpty ||
        _disposed) {
      return;
    }

    await _playSongFromNotification(
      _playlistManager.getPreviousSongFromPlaylist(currentSong),
    );
  }

  Future<void> _playSongFromNotification(MusicFile song) async {
    if (_disposed || !_isPlaybackAvailable || !songs.contains(song)) {
      return;
    }

    _currentSong = song;
    _notifyListeners();
    await _soundCollectionManager.selectAndPlaySong(song);
  }

  Future<void> _onPlaybackStateChanged(PlaybackState value) async {
    if (!_isPlaybackAvailable || _disposed) {
      return;
    }

    if (currentPlaylistName != allFilesPlaylistName &&
        value.processingState == AudioProcessingState.completed) {
      final currentSong = _currentSong;
      if (currentSong != null && songs.isNotEmpty) {
        final songToPlay = _isLoopModeOn
            ? currentSong
            : _playlistManager.getNextSongFromPlaylist(currentSong);
        _currentSong = songToPlay;
        await _soundCollectionManager.selectAndPlaySong(songToPlay);
      }
    }

    _notifyListeners();
  }

  void _onPlaylistChanged() {
    if (_isPlaybackAvailable) {
      _applyLoopModeForCurrentPlaylist();
    }
    _notifyListeners();
  }

  Future<void> _stopAndResetPlayback() async {
    _isPlaybackAvailable = false;
    _currentSong = null;
    _notifyListeners();
    await _soundCollectionManager.stopPlayback();
  }

  void _applyLoopModeForCurrentPlaylist() {
    final loopMode =
        currentPlaylistName == allFilesPlaylistName ? true : _isLoopModeOn;
    unawaited(_soundCollectionManager.setLoopMode(loopMode));
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _playlistManager.removeListener(_onPlaylistChanged);
    unawaited(_playbackSubscription?.cancel());
    _soundCollectionManager.setNotificationSkipHandlers();
    super.dispose();
  }
}
