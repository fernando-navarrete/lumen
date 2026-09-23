/// A downloadable product (a game or one of its DLCs) within a build. App-owned
/// counterpart of the bridge's `DownloadableProduct` (`package:gogdl_flutter`)
/// — see `GogdlBackend` (`lib/state/gogdl_backend.dart`) for the adapter.
class DownloadableProduct {
  final int id;
  final String name;
  final String productType;

  const DownloadableProduct({
    required this.id,
    required this.name,
    required this.productType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadableProduct &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          productType == other.productType;

  @override
  int get hashCode => Object.hash(id, name, productType);
}
