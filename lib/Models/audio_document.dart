final class AudioDocument {
  const AudioDocument({
    required this.contentUri,
    required this.displayName,
    required this.volumeName,
    this.relativePath,
    this.mimeType,
    this.size,
  });

  factory AudioDocument.fromMap(Map<Object?, Object?> map) {
    return AudioDocument(
      contentUri: Uri.parse(map['contentUri']! as String),
      displayName: map['displayName']! as String,
      relativePath: map['relativePath'] as String?,
      volumeName: map['volumeName']! as String,
      mimeType: map['mimeType'] as String?,
      size: map['size'] as int?,
    );
  }

  final Uri contentUri;
  final String displayName;
  final String? relativePath;
  final String volumeName;
  final String? mimeType;
  final int? size;
}
