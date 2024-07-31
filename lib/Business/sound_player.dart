import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  List<MusicFile> availableSongs = [];
  List<MusicFile> playedSongs = [];
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
    while (true) {
      MusicFile randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];

      if(!playedSongs.contains(randomMusicFile)) {
        if(playedSongs.length < 20) {
          playedSongs.add(randomMusicFile);
          currentlySelectedSong = randomMusicFile;

          return playSong();
        }
        else if(playedSongs.length >= 20) {
          playedSongs.removeAt(0);
          playedSongs.add(randomMusicFile);
          currentlySelectedSong = randomMusicFile;

          return playSong();
        }
      }
      else {
        randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];
      }
    }
  }

  PlayerStateEnum selectAndPlaySong(int songIndex) {
    currentlySelectedSong = availableSongs[songIndex];

    return playSong();
  }
}