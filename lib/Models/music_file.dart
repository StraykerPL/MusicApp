import 'package:strayker_music/Constants/constants.dart';

interface class MusicFile {
  String nameLocal = Constants.stringEmpty;
  String filePathLocal = Constants.stringEmpty;

  String get name => nameLocal;
  String get filePath => filePathLocal;
  set filePath(String value) => {
    filePathLocal = value,
    nameLocal = _getFileName(value)
  };

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