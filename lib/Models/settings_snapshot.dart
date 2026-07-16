import 'dart:collection';

final class SettingsSnapshot {
  SettingsSnapshot({
    required this.playedSongsMaxAmount,
    required List<String> storageLocations,
  }) : storageLocations = UnmodifiableListView(List.of(storageLocations));

  final int playedSongsMaxAmount;
  final UnmodifiableListView<String> storageLocations;
}
