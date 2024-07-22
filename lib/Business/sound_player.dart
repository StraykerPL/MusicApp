import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  List<MusicFile> availableSongs = [];
  late MusicFile _currentlySelectedSong;

  void playSong() {
    _player.stop();
    _player.setUrl(_currentlySelectedSong.filePath);
    _player.play();
  }

  void pauseSong() {
    if(_player.playing) {
      _player.pause();
    }
    else {
      _player.play();
    }
  }

  void playRandomMusic() {
    _currentlySelectedSong = availableSongs[Random().nextInt(availableSongs.length)];
    playSong();
  }

  void setCurrentSong(int songIndex) {
    _currentlySelectedSong = availableSongs[songIndex];
    playSong();
  }
}