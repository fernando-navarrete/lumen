/// A single build (version) of a game, as listed by GOG.
///
/// App-owned replacement for the bridge's `GameBuild` — see
/// `lib/state/gog_backend.dart`. Field set mirrors the bridge type exactly,
/// with `releaseDateTimestamp` as a plain `int` instead of `BigInt`.
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
}
