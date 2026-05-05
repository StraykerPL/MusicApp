import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Shared/storage_path_policy.dart';

void main() {
  group('StoragePathPolicy', () {
    test('accepts normal shared media folders', () {
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Music',
        ),
        isTrue,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation('/sdcard/Download'),
        isTrue,
      );
    });

    test('rejects Android shared storage folder and descendants', () {
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Android',
        ),
        isFalse,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Android/data',
        ),
        isFalse,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation('/sdcard/Android/obb'),
        isFalse,
      );
    });

    test('rejects Android folder on external storage volumes', () {
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/1234-5678/Android',
        ),
        isFalse,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/1234-5678/Android/data',
        ),
        isFalse,
      );
    });

    test('rejects paths that contain restricted Android folder segment', () {
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Music/Android',
        ),
        isFalse,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Music/Android/data',
        ),
        isFalse,
      );
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          '/storage/emulated/0/Music/Androids',
        ),
        isTrue,
      );
    });

    test('normalizes separators and path case before validation', () {
      expect(
        StoragePathPolicy.isSelectableStorageLocation(
          r'\storage\emulated\0\ANDROID\data',
        ),
        isFalse,
      );
    });

    test('rejects empty storage paths', () {
      expect(StoragePathPolicy.isSelectableStorageLocation(''), isFalse);
      expect(StoragePathPolicy.isSelectableStorageLocation('   '), isFalse);
    });
  });
}
