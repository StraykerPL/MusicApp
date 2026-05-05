import 'package:path/path.dart' as path;

abstract final class StoragePathPolicy {
  static final path.Context _posixPath = path.Context(style: path.Style.posix);

  static const String restrictedStorageLocationMessage =
      'This folder is restricted by the system. Select a media folder such as Music, Download, or another folder outside Android.';

  static bool isSelectableStorageLocation(String storagePath) {
    return getValidationError(storagePath) == null;
  }

  static bool canDisplayInPicker(String storagePath) {
    return !_isRestrictedAndroidStoragePath(storagePath);
  }

  static String? getValidationError(String storagePath) {
    if (storagePath.trim().isEmpty) {
      return 'Storage path cannot be empty.';
    }

    final normalizedPath = _normalize(storagePath);
    if (normalizedPath.isEmpty) {
      return 'Storage path cannot be empty.';
    }

    if (_isRestrictedAndroidStoragePath(normalizedPath)) {
      return restrictedStorageLocationMessage;
    }

    return null;
  }

  static bool _isRestrictedAndroidStoragePath(String storagePath) {
    final normalizedPath = _normalize(storagePath).toLowerCase();
    final pathSegments = _posixPath.split(normalizedPath).where((segment) {
      return segment.isNotEmpty && segment != _posixPath.separator;
    });

    if (pathSegments.contains('android')) {
      return true;
    }

    final restrictedRoots = <String>[
      '/sdcard/android',
      '/mnt/sdcard/android',
      '/storage/self/primary/android',
      '/storage/emulated/0/android',
      '/',
    ];

    for (final restrictedRoot in restrictedRoots) {
      if (_isSameOrChildPath(normalizedPath, restrictedRoot)) {
        return true;
      }
    }

    final externalStorageRoot = RegExp(r'^/storage/[^/]+/android($|/)');
    return externalStorageRoot.hasMatch(normalizedPath);
  }

  static bool _isSameOrChildPath(String storagePath, String parentPath) {
    return storagePath == parentPath || storagePath.startsWith('$parentPath/');
  }

  static String _normalize(String storagePath) {
    final withPosixSeparators = storagePath.trim().replaceAll(r'\', '/');
    return _posixPath.normalize(withPosixSeparators);
  }
}
