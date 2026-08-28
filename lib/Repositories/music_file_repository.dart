import 'package:strayker_music/Models/audio_permission_result.dart';
import 'package:strayker_music/Services/media_store_service.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Models/storage_permission_denied_exception.dart';

class MusicFileRepository {
  MusicFileRepository({MediaStoreService? mediaStore})
      : _mediaStore = mediaStore ?? const MediaStoreService();

  final MediaStoreService _mediaStore;

  Future<MusicScanResult> getAll(List<String> storageLocations) async {
    final permissionResult = await _mediaStore.requestRequiredAudioPermission();

    if (permissionResult != AudioPermissionResult.granted) {
      throw StoragePermissionDeniedException(permissionResult);
    }

    final scan = await _mediaStore.listAudio(storageLocations);
    final songsByUri = <Uri, MusicFile>{};

    for (final document in scan.documents) {
      songsByUri.putIfAbsent(
        document.contentUri,
        () => MusicFile(
          sourceUri: document.contentUri,
          displayName: document.displayName,
        ),
      );
    }

    return MusicScanResult(
      songs: songsByUri.values.toList(growable: false),
      skippedLocations: scan.skippedSourceIds,
    );
  }
}
