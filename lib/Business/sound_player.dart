import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  List<MusicFile> availableSongs = [];
  MusicFile? currentlySelectedSong;

  SoundPlayer({required List<MusicFile> songs}) {
    availableSongs = songs;
    _player.setLoopMode(LoopMode.all);
  }

  PlayerStateEnum playSong() {
    _player.stop();
    _player.setUrl(currentlySelectedSong!.filePath);
    _player.play();

    return PlayerStateEnum.playing;
  }

  PlayerStateEnum resumeOrPauseSong() {
    if(_player.playing) {
      _player.pause();

      return PlayerStateEnum.paused;
    }
    else {
      _player.play();

      return PlayerStateEnum.playing;
    }
  }

  PlayerStateEnum playRandomMusic() {
    currentlySelectedSong = availableSongs[Random().nextInt(availableSongs.length)];

    return playSong();
  }

  PlayerStateEnum selectAndPlaySong(int songIndex) {
    currentlySelectedSong = availableSongs[songIndex];

    return playSong();
  }
}