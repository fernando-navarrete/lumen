/// A Proton-GE release available for download from GitHub.
///
/// App-owned replacement for the bridge's `ProtonRelease` — see
/// `lib/state/gog_backend.dart`. `downloadSize` is a plain `int` instead of
/// `BigInt`.
class ProtonRelease {
  final String tagName;
  final int downloadSize;

  const ProtonRelease({required this.tagName, required this.downloadSize});
}
