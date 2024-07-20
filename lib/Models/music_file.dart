interface class MusicFile {
  String nameLocal = "", filePathLocal = "";

  String get name => nameLocal;
  set name(String value) => nameLocal = value;
  String get filePath => filePathLocal;
  set filePath(String value) => filePathLocal = value;
}