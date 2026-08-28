final class AudioFolder {
  const AudioFolder({
    required this.sourceId,
    required this.displayPath,
    required this.volumeName,
    required this.relativePath,
  });

  factory AudioFolder.fromMap(Map<Object?, Object?> map) {
    return AudioFolder(
      sourceId: map['sourceId']! as String,
      displayPath: map['displayPath']! as String,
      volumeName: map['volumeName']! as String,
      relativePath: map['relativePath']! as String,
    );
  }

  final String sourceId;
  final String displayPath;
  final String volumeName;
  final String relativePath;
}
