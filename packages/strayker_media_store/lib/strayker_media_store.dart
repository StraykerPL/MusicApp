import 'package:flutter/services.dart';

enum AudioPermissionResult { granted, denied, permanentlyDenied }

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

final class AudioScanResult {
  const AudioScanResult({
    required this.documents,
    required this.skippedSourceIds,
  });

  final List<AudioDocument> documents;
  final List<String> skippedSourceIds;
}

class StraykerMediaStore {
  const StraykerMediaStore({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel(
              'pl.straykersoftware.strayker_music/media_store',
            );

  final MethodChannel _channel;

  Future<AudioScanResult> listAudio(List<String> sourceIds) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'listAudio',
      <String, Object?>{'sourceIds': sourceIds},
    );
    if (result == null) {
      throw PlatformException(
        code: 'QUERY_FAILED',
        message: 'MediaStore returned no scan result.',
      );
    }
    final documents = (result['documents']! as List<Object?>)
        .cast<Map<Object?, Object?>>()
        .map(AudioDocument.fromMap)
        .toList(growable: false);
    final skipped = (result['skippedSourceIds']! as List<Object?>)
        .cast<String>()
        .toList(growable: false);
    return AudioScanResult(documents: documents, skippedSourceIds: skipped);
  }

  Future<List<AudioFolder>> listAudioFolders() async {
    final result = await _channel.invokeListMethod<Object?>('listAudioFolders');
    return (result ?? const <Object?>[])
        .cast<Map<Object?, Object?>>()
        .map(AudioFolder.fromMap)
        .toList(growable: false);
  }

  Future<bool> hasRequiredAudioPermission() async {
    return await _channel.invokeMethod<bool>('hasRequiredAudioPermission') ??
        false;
  }

  Future<AudioPermissionResult> requestRequiredAudioPermission() async {
    final value = await _channel.invokeMethod<String>(
      'requestRequiredAudioPermission',
    );
    return switch (value) {
      'granted' => AudioPermissionResult.granted,
      'denied' => AudioPermissionResult.denied,
      'permanentlyDenied' => AudioPermissionResult.permanentlyDenied,
      _ => throw PlatformException(
          code: 'INVALID_RESULT',
          message: 'Unknown permission result: $value',
        ),
    };
  }
}
