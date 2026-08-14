import 'dart:async';
import 'dart:collection';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_load_status.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Services/music_library_service.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';

final class PlaylistViewModel extends ChangeNotifier {
  PlaylistViewModel({
    required PlaylistManager playlistManager,
    required SoundCollectionManager soundCollectionManager,
    required MusicLibraryService musicLibraryService,
  })  : _playlistManager = playlistManager,
        _soundCollectionManager = soundCollectionManager,
        _musicLibraryService = musicLibraryService;

  final PlaylistManager _playlistManager;
  final SoundCollectionManager _soundCollectionManager;
  final MusicLibraryService _musicLibraryService;

  List<MusicFile> _allSongs = <MusicFile>[];
  MusicLoadStatus _musicLoadStatus = MusicLoadStatus.initial;
  Object? _musicLoadError;
  Object? _playbackError;
  List<String> _skippedStorageLocations = <String>[];
  Future<void>? _musicLoadInFlight;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  MusicFile? _currentSong;
  bool _isSearchVisible = false;
  bool _isLoopModeOn = false;
  bool _isPlaybackAvailable = true;
  bool _suppressPlaylistNotification = false;
  String _searchQuery = '';
  bool _initialized = false;
  bool _disposed = false;

  UnmodifiableListView<MusicFile> get allSongs =>
      UnmodifiableListView<MusicFile>(_allSongs);
  MusicLoadStatus get musicLoadStatus => _musicLoadStatus;
  Object? get musicLoadError => _musicLoadError;
  Object? get playbackError => _playbackError;
  UnmodifiableListView<String> get skippedStorageLocations =>
      UnmodifiableListView<String>(_skippedStorageLocations);
  String get currentPlaylistName => _playlistManager.currentPlaylist;
  UnmodifiableListView<String> get availablePlaylists =>
      UnmodifiableListView<String>(_playlistManager.availablePlaylists);
  UnmodifiableListView<MusicFile> get songs =>
      UnmodifiableListView<MusicFile>(_playlistManager.currentPlaylistSongs);
  UnmodifiableListView<MusicFile> get displayedSongs =>
      UnmodifiableListView<MusicFile>(
        _playlistManager.currentPlaylistSongs.where(
          (MusicFile song) =>
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
  bool get canRemoveSongs => currentPlaylistName != Constants.allFilesListName;
  bool get showsLoopControl =>
      currentPlaylistName != Constants.allFilesListName;

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
    await _loadMusicLibrary();
    await _playlistManager.loadAvailablePlaylists();
    _notifyListeners();
  }

  Future<void> retryInitialMusicLoad() async {
    if (_musicLoadStatus != MusicLoadStatus.failed) {
      return;
    }

    await _loadMusicLibrary();
  }

  Future<void> _loadMusicLibrary() {
    final Future<void>? activeLoad = _musicLoadInFlight;
    if (activeLoad != null) {
      return activeLoad;
    }

    final Future<void> newLoad = _performMusicLoad();
    _musicLoadInFlight = newLoad;

    return newLoad.whenComplete(() {
      if (identical(_musicLoadInFlight, newLoad)) {
        _musicLoadInFlight = null;
      }
    });
  }

  Future<void> _performMusicLoad() async {
    _musicLoadStatus = MusicLoadStatus.loading;
    _musicLoadError = null;
    _notifyListeners();

    try {
      final MusicScanResult result = await _musicLibraryService.loadMusic();
      final List<MusicFile> loadedSongs =
          List<MusicFile>.unmodifiable(result.songs);

      _suppressPlaylistNotification = true;
      try {
        await _playlistManager.replaceAllSongs(loadedSongs);
      } finally {
        _suppressPlaylistNotification = false;
      }

      await _reconcileCurrentSong(loadedSongs);
      _soundCollectionManager.reconcileSongs(loadedSongs);
      _allSongs = loadedSongs;
      _skippedStorageLocations =
          List<String>.unmodifiable(result.skippedLocations);
      _musicLoadStatus = MusicLoadStatus.ready;
    } on Object catch (error, stackTrace) {
      _musicLoadError = error;
      _musicLoadStatus = MusicLoadStatus.failed;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while loading the music library'),
        ),
      );
    } finally {
      _notifyListeners();
    }
  }

  Future<void> _reconcileCurrentSong(List<MusicFile> loadedSongs) async {
    if (currentSong == null) {
      return;
    }

    for (final MusicFile song in loadedSongs) {
      if (song.filePath == currentSong!.filePath) {
        _currentSong = song;

        return;
      }
    }

    await _soundCollectionManager.stopPlayback();
    _currentSong = null;
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
    _playbackError = null;
    _notifyListeners();
    await _playSelectedSong(song);
  }

  Future<void> _playSelectedSong(MusicFile song) async {
    try {
      await _soundCollectionManager.selectAndPlaySong(song);
    } on Object catch (error, stackTrace) {
      if (_currentSong?.filePath == song.filePath) {
        _currentSong = null;
        _playbackError = error;
        _notifyListeners();
      }

      // TODO: Should we handle errors directly? Like this?
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while selecting an audio source'),
        ),
      );
    }
  }

  Future<void> shuffle() async {
    if (!_isPlaybackAvailable) {
      return;
    }

    final MusicFile? song = await _soundCollectionManager.getRandomMusic(
      _playlistManager.currentPlaylistSongs,
    );

    if (song == null || _disposed || !_isPlaybackAvailable) {
      return;
    }

    _currentSong = song;
    _notifyListeners();
    await _playSelectedSong(song);
  }

  Future<void> resumeOrPause() async {
    if (canControlCurrentSong) {
      await _soundCollectionManager.resumeOrPauseSong();
    }
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

  Future<void> enterSettings() => _stopAndResetPlayback();

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

  Future<void> addSongToPlaylist(String playlistName, MusicFile song) =>
      _playlistManager.addSongToPlaylistByName(playlistName, song.filePath);

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
    final MusicFile? currentSong = _currentSong;

    if (!_canNavigateFrom(currentSong)) {
      return;
    }

    await _playSongFromNotification(
      _playlistManager.getNextSongFromPlaylist(currentSong!),
    );
  }

  Future<void> playPreviousSongFromNotification() async {
    final MusicFile? currentSong = _currentSong;

    if (!_canNavigateFrom(currentSong)) {
      return;
    }

    await _playSongFromNotification(
      _playlistManager.getPreviousSongFromPlaylist(currentSong!),
    );
  }

  bool _canNavigateFrom(MusicFile? song) =>
      _isPlaybackAvailable &&
      song != null &&
      songs.contains(song) &&
      songs.isNotEmpty &&
      !_disposed;

  Future<void> _playSongFromNotification(MusicFile song) async {
    if (_disposed || !_isPlaybackAvailable || !songs.contains(song)) {
      return;
    }

    _currentSong = song;
    _notifyListeners();
    await _playSelectedSong(song);
  }

  Future<void> _onPlaybackStateChanged(PlaybackState value) async {
    if (!_isPlaybackAvailable || _disposed) {
      return;
    }

    if (currentPlaylistName != Constants.allFilesListName &&
        value.processingState == AudioProcessingState.completed) {
      final MusicFile? currentSong = _currentSong;
      
      if (currentSong != null && songs.isNotEmpty) {
        final MusicFile songToPlay = _isLoopModeOn
            ? currentSong
            : _playlistManager.getNextSongFromPlaylist(currentSong);
        _currentSong = songToPlay;
        await _playSelectedSong(songToPlay);
      }
    }

    _notifyListeners();
  }

  void _onPlaylistChanged() {
    if (_suppressPlaylistNotification) {
      return;
    }

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
    final bool loopMode = currentPlaylistName == Constants.allFilesListName
        ? true
        : _isLoopModeOn;
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
