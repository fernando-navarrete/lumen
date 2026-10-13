/// What removing products from an install deleted. App-owned counterpart of
/// the bridge's `ProductRemoval` (`package:gogdl_flutter`) — see
/// `GogdlBackend` (`lib/state/gogdl_backend.dart`) for the adapter. Counts
/// only what that call removed: files already gone, and files a kept product
/// also lists, are in neither number.
class ProductRemoval {
  final int filesRemoved;
  final int bytesFreed;

  const ProductRemoval({required this.filesRemoved, required this.bytesFreed});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductRemoval &&
          runtimeType == other.runtimeType &&
          filesRemoved == other.filesRemoved &&
          bytesFreed == other.bytesFreed;

  @override
  int get hashCode => Object.hash(filesRemoved, bytesFreed);
}
