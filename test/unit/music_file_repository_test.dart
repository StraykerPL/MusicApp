import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_media_store/strayker_media_store.dart';
import 'package:strayker_music/Models/storage_permission_denied_exception.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';

final class FakeMediaStore extends StraykerMediaStore {
  FakeMediaStore({
    this.permission = AudioPermissionResult.granted,
    this.scan = const AudioScanResult(
      documents: <AudioDocument>[],
      skippedSourceIds: <String>[],
    ),
  });

  AudioPermissionResult permission;
  AudioScanResult scan;
  List<String>? requestedSources;

  @override
  Future<AudioPermissionResult> requestRequiredAudioPermission() async =>
      permission;

  @override
  Future<AudioScanResult> listAudio(List<String> sourceIds) async {
    requestedSources = sourceIds;
    return scan;
  }
}

void main() {
  test('maps MediaStore documents to content URI song identities', () async {
    final mediaStore = FakeMediaStore(
      scan: AudioScanResult(
        documents: <AudioDocument>[
          AudioDocument(
            contentUri: Uri.parse(
              'content://media/external_primary/audio/media/42',
            ),
            displayName: 'Alpha.MP3',
            relativePath: 'Music/',
            volumeName: 'external_primary',
          ),
        ],
        skippedSourceIds: const <String>[],
      ),
    );
    final repository = MusicFileRepository(mediaStore: mediaStore);

    final result = await repository.getAll(
      const <String>['mediastore://external_primary/Music/'],
    );

    expect(mediaStore.requestedSources, [
      'mediastore://external_primary/Music/',
    ]);
    expect(result.songs.single.name, 'Alpha');
    expect(
      result.songs.single.sourceUri.toString(),
      'content://media/external_primary/audio/media/42',
    );
    expect(
      result.songs.single.mediaItemMetaData.id,
      'content://media/external_primary/audio/media/42',
    );
  });

  test('keeps accessible songs while reporting skipped sources', () async {
    final mediaStore = FakeMediaStore(
      scan: const AudioScanResult(
        documents: <AudioDocument>[],
        skippedSourceIds: <String>['mediastore://AAAA-BBBB/Music/'],
      ),
    );
    final result = await MusicFileRepository(mediaStore: mediaStore).getAll(
      const <String>['mediastore://AAAA-BBBB/Music/'],
    );

    expect(result.songs, isEmpty);
    expect(result.skippedLocations, ['mediastore://AAAA-BBBB/Music/']);
  });

  test('throws a typed failure when storage permission is denied', () async {
    final repository = MusicFileRepository(
      mediaStore: FakeMediaStore(permission: AudioPermissionResult.denied),
    );

    expect(
      repository.getAll(const <String>[]),
      throwsA(isA<StoragePermissionDeniedException>()),
    );
  });

  test('permanent denial also fails closed', () async {
    final mediaStore = FakeMediaStore(
      permission: AudioPermissionResult.permanentlyDenied,
    );

    await expectLater(
      MusicFileRepository(mediaStore: mediaStore).getAll(
        const <String>['mediastore://external_primary/Music/'],
      ),
      throwsA(isA<StoragePermissionDeniedException>()),
    );
    expect(mediaStore.requestedSources, isNull);
  });
}
