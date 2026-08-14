class StoragePermissionDeniedException implements Exception {
  const StoragePermissionDeniedException(this.status);

  final Object status;

  @override
  String toString() => 'Storage permission was denied ($status).';
}
