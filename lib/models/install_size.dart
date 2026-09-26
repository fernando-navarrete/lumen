/// What installing a build would take. App-owned counterpart of the bridge's
/// `InstallSize` (`package:gogdl_flutter`) — see `GogdlBackend`
/// (`lib/state/gogdl_backend.dart`) for the adapter. Sizes are plain `int`s
/// here (the bridge's `BigInt`). `diskBytes` is what the download's own
/// free-space check compares against; `downloadBytes` is the compressed
/// transfer.
class InstallSize {
  final int downloadBytes;
  final int diskBytes;

  const InstallSize({required this.downloadBytes, required this.diskBytes});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallSize &&
          runtimeType == other.runtimeType &&
          downloadBytes == other.downloadBytes &&
          diskBytes == other.diskBytes;

  @override
  int get hashCode => Object.hash(downloadBytes, diskBytes);
}
