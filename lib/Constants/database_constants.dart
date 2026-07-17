abstract final class DatabaseConstants {
  static const String settingsTableName = "settings";
  static const String storagePathsTableName = "storageLocations";
  static const String playlistsTableName = "playlists";
  static const String playlistSongsTableName = "playlistSongs";
  static const String playedSongsMaxAmountTableValueName =
      "playedSongsMaxAmount";
  static const List<String> soundStorageLocationsDefault = [
    "/storage/emulated/0/Music"
  ];
  static const int playedSongsMaxAmountDefault = 0;
}
