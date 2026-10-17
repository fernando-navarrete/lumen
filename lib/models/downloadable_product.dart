/// A downloadable product (a game or one of its DLCs) within a build. App-owned
/// counterpart of the bridge's `DownloadableProduct` (`package:gogdl_flutter`)
/// — see `GogdlBackend` (`lib/state/gogdl_backend.dart`) for the adapter.
/// What a [DownloadableProduct] is. App-owned counterpart of the bridge's
/// `ProductType`; `other` is anything that is neither the game nor a DLC.
enum ProductType {
  game('Game'),
  dlc('DLC'),
  other('Other');

  const ProductType(this.label);

  final String label;
}

class DownloadableProduct {
  final int id;
  final String name;
  final ProductType productType;

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
