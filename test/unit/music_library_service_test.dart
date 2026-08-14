import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';
import 'package:strayker_music/Services/music_library_service.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

class FakeMusicFileRepository extends MusicFileRepository {
  FakeMusicFileRepository(this.result);

  final MusicScanResult result;

  @override
  Future<MusicScanResult> getAll(List<String> storageLocations) async => result;
}

void main() {
  test('loadMusic returns a sorted immutable result without retaining state',
      () async {
    final service = MusicLibraryService(
      musicFileRepository: FakeMusicFileRepository(
        MusicScanResult(
          songs: <MusicFile>[
            createSong('/music/zeta.mp3'),
            createSong('/music/alpha.mp3'),
          ],
          skippedLocations: const <String>['/missing'],
        ),
      ),
      settingsSnapshotRepository: FakeSettingsSnapshotRepository(),
    );

    final result = await service.loadMusic();

    expect(result.songs.map((song) => song.name), <String>['alpha', 'zeta']);
    expect(result.skippedLocations, <String>['/missing']);
    expect(
      () => result.songs.add(createSong('/music/new.mp3')),
      throwsUnsupportedError,
    );
    expect(() => result.skippedLocations.add('/other'), throwsUnsupportedError);
  });
}
