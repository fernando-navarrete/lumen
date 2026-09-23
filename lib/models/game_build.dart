/// A single build of a game, as listed by GOG. App-owned counterpart of the
/// bridge's `GameBuild` (`package:gogdl_flutter`) — see `GogdlBackend`
/// (`lib/state/gogdl_backend.dart`) for the adapter. `releaseDateTimestamp`
/// is a plain `int` here (the bridge's `PlatformInt64`).
class GameBuild {
  final String buildId;
  final String versionName;
  final String releaseDate;
  final int releaseDateTimestamp;

  const GameBuild({
    required this.buildId,
    required this.versionName,
    required this.releaseDate,
    required this.releaseDateTimestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameBuild &&
          runtimeType == other.runtimeType &&
          buildId == other.buildId &&
          versionName == other.versionName &&
          releaseDate == other.releaseDate &&
          releaseDateTimestamp == other.releaseDateTimestamp;

  @override
  int get hashCode =>
      Object.hash(buildId, versionName, releaseDate, releaseDateTimestamp);
}
