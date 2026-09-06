/// A DLC or base-game product that can be selected for download, as listed
/// by GOG for a given build.
///
/// App-owned replacement for the bridge's `DownloadableProduct` — see
/// `lib/state/gog_backend.dart`.
class DownloadableProduct {
  final String id;
  final String name;
  final String productType;

  const DownloadableProduct({
    required this.id,
    required this.name,
    required this.productType,
  });
}
