abstract final class DatabaseConstants {
  static String settingsTableName = "settings";
  static String storagePathsTableName = "storageLocations";
  static String playlistsTableName = "playlists";
  static String playlistSongsTableName = "playlistSongs";
  static String playedSongsMaxAmountTableValueName = "playedSongsMaxAmount";
  static List<String> soundStorageLocationsDefault = ["/storage/emulated/0/Music"];
  static const int playedSongsMaxAmountDefault = 0;
}