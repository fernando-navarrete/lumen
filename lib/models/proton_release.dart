/// A published Proton-GE release. App-owned counterpart of the bridge's
/// `ProtonRelease` (`package:gogdl_flutter`) — see `GogdlBackend`
/// (`lib/state/gogdl_backend.dart`) for the adapter. `downloadSize` is a plain
/// `int` here (the bridge's `BigInt`).
class ProtonRelease {
  final String tagName;
  final int downloadSize;

  const ProtonRelease({required this.tagName, required this.downloadSize});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtonRelease &&
          runtimeType == other.runtimeType &&
          tagName == other.tagName &&
          downloadSize == other.downloadSize;

  @override
  int get hashCode => Object.hash(tagName, downloadSize);
}
