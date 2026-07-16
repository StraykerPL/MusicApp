final class Playlist {
  const Playlist({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
