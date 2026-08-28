import 'package:flutter/services.dart';
import 'package:strayker_music/Models/audio_document.dart';
import 'package:strayker_music/Models/audio_folder.dart';
import 'package:strayker_music/Models/audio_permission_result.dart';
import 'package:strayker_music/Models/audio_scan_result.dart';

class MediaStoreService {
  const MediaStoreService({MethodChannel? channel})
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
