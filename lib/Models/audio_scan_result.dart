import 'package:strayker_music/Models/audio_document.dart';

final class AudioScanResult {
  const AudioScanResult({
    required this.documents,
    required this.skippedSourceIds,
  });

  final List<AudioDocument> documents;
  final List<String> skippedSourceIds;
}
