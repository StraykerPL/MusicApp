import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Constants/constants.dart';

final class MusicFile {
  final Uri sourceUri;
  final String name;
  final MediaItem mediaItemMetaData;

  MusicFile({required this.sourceUri, required String displayName})
      : name = _titleFromDisplayName(displayName),
        mediaItemMetaData = MediaItem(
          id: sourceUri.toString(),
          title: _titleFromDisplayName(displayName),
        ) {
    if (sourceUri.scheme != 'content' || sourceUri.authority.isEmpty) {
      throw ArgumentError.value(
        sourceUri,
        'sourceUri',
        'Music source must be an Android content URI.',
      );
    }
  }

  static String _titleFromDisplayName(String displayName) {
    return displayName.toLowerCase().endsWith(Constants.stringMp3Extension)
        ? displayName.substring(
            0,
            displayName.length - Constants.stringMp3Extension.length,
          )
        : displayName;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicFile && other.sourceUri == sourceUri;

  @override
  int get hashCode => sourceUri.hashCode;
}
