import 'dart:math';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundFilesManager {
  late final SoundPlayer _soundPlayer;
  List<MusicFile> availableSongs = [];
  List<MusicFile> playedSongs = [];

  SoundFilesManager({required SoundPlayer player, required List<MusicFile> songs}) {
    _soundPlayer = player;
    availableSongs = songs;
    availableSongs.sort((firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
  }

  PlayerStateEnum playRandomMusic() {
    while (true) {
      MusicFile randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];

      if(!playedSongs.contains(randomMusicFile)) {
        if(playedSongs.length < 20) {
          playedSongs.add(randomMusicFile);
          _soundPlayer.currentSong = randomMusicFile;

          return _soundPlayer.playNewSong();
        }
        else if(playedSongs.length >= 20) {
          playedSongs.removeAt(0);
          playedSongs.add(randomMusicFile);
          _soundPlayer.currentSong = randomMusicFile;

          return _soundPlayer.playNewSong();
        }
      }
      else {
        randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];
      }
    }
  }

  PlayerStateEnum selectAndPlaySong(String songName) {
    _soundPlayer.currentSong = availableSongs.singleWhere((songFile) => songFile.name == songName);

    return _soundPlayer.playNewSong();
  }
}