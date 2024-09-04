import 'package:just_audio_background/just_audio_background.dart';
import 'package:strayker_music/Constants/constants.dart';

interface class MusicFile {
  late MediaItem _mediaItem;
  String _nameLocal = Constants.stringEmpty;
  String _filePathLocal = Constants.stringEmpty;

  String get name => _nameLocal;
  String get filePath => _filePathLocal;
  set filePath(String value) => {
    _filePathLocal = value,
    _nameLocal = _getFileName(value),
    _mediaItem = MediaItem(id: "1", title: _nameLocal)
  };
  MediaItem get mediaItemMetaData => _mediaItem;

  String _getFileName(String givenPath) {
    String name = givenPath;

    if(name.endsWith(Constants.stringMp3Extension)) {
      name = name.replaceAll(
        Constants.stringMp3Extension,
        Constants.stringEmpty);
    }

    for (var i = name.length - 1; i > 0; i--) {
      if(name[i] == '/') {
        name = name.substring(i + 1);

        break;
      }
    }

    return name;
  }
}