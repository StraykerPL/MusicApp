import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart' as path;
import 'package:strayker_music/Constants/constants.dart';

interface class MusicFile {
  late MediaItem _mediaItem;
  String _nameLocal = Constants.stringEmpty;
  String _filePathLocal = Constants.stringEmpty;

  String get name => _nameLocal;
  String get filePath => _filePathLocal;
  set filePath(String value) {
    _filePathLocal = path.normalize(path.absolute(value));
    _nameLocal = _getFileName(_filePathLocal);
    _mediaItem = MediaItem(id: _filePathLocal, title: _nameLocal);
  }

  MediaItem get mediaItemMetaData => _mediaItem;

  String _getFileName(String givenPath) {
    String name = givenPath;

    final String fileName = path.basename(name);
    return path.extension(fileName).toLowerCase() ==
            Constants.stringMp3Extension
        ? path.basenameWithoutExtension(fileName)
        : fileName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicFile && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}
