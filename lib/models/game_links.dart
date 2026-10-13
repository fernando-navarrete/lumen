/// A game's image links. App-owned counterpart of the bridge's `GameLinks`
/// (`package:gogdl_flutter`) — see `GogdlBackend` (`lib/state/gogdl_backend.dart`)
/// for the adapter. Both links come from one request; an empty string means
/// "no image".
class GameLinks {
  final String boxart;
  final String background;

  const GameLinks({required this.boxart, required this.background});

  /// What a failed lookup falls back to.
  static const empty = GameLinks(boxart: '', background: '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameLinks &&
          runtimeType == other.runtimeType &&
          boxart == other.boxart &&
          background == other.background;

  @override
  int get hashCode => Object.hash(boxart, background);
}
