import 'package:flutter/foundation.dart';
import 'package:lumen/models/proton_release.dart';

/// One page of Proton-GE releases. App-owned counterpart of the bridge's
/// `ProtonReleasePage` (`package:gogdl_flutter`) — see `GogdlBackend`
/// (`lib/state/gogdl_backend.dart`) for the adapter. [hasMore] is true when
/// GitHub returned a full page, even if every release on it was left out of
/// [releases] (no suitable asset), so an empty page isn't the end of the list.
class ProtonReleasePage {
  final List<ProtonRelease> releases;
  final bool hasMore;

  const ProtonReleasePage({required this.releases, required this.hasMore});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtonReleasePage &&
          runtimeType == other.runtimeType &&
          listEquals(releases, other.releases) &&
          hasMore == other.hasMore;

  @override
  int get hashCode => Object.hash(Object.hashAll(releases), hasMore);
}
