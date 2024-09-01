import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  late AudioSession _session;
  MusicFile? currentSong;

  SoundPlayer() {
    _player.setLoopMode(LoopMode.all);
    AudioSession.instance.then((completedSession) {
      completedSession.configure(const AudioSessionConfiguration.music());
      _session = completedSession;

      return completedSession;
    });
  }

  PlayerStateEnum playNewSong() {
    if(currentSong == null) {
      return PlayerStateEnum.musicNotLoaded;
    }

    _player.stop();
    _session.setActive(true).then((onValue) {
      if(onValue) {
        _player.setAudioSource(
          AudioSource.file(
            currentSong!.filePath,
            tag: currentSong!.mediaItemMetaData,
          )
        ).whenComplete(() {
          _player.play();
        });
      }
    });

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
}