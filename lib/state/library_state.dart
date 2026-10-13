import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lumen/common/async_limiter.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/gog_state.dart';

/// Thrown by the metadata providers when [GogState] reports a failure by
/// returning `null`, so the UI sees an `AsyncError` instead of a value.
class MetadataUnavailableError implements Exception {
  const MetadataUnavailableError(this.what);

  final String what;

  @override
  String toString() => "Couldn't load $what";
}

/// Riverpod 3 retries a failed provider on its own (up to 10 times with
/// backoff). That would hammer GOG while the user stares at an error and
/// makes widget tests pump forever, so every provider here opts out: Retry
/// is always an explicit `ref.invalidate`.
Duration? noRetry(int retryCount, Object error) => null;

T _orThrow<T>(T? value, String what) {
  if (value == null) {
    throw MetadataUnavailableError(what);
  }
  return value;
}

/// The owned games' ids, sorted. These providers aren't `autoDispose`, so
/// the result lives for the session and `ref.invalidate` is the refresh.
///
/// An empty list is real data, not an error — but upstream silently drops a
/// game whose gamesdb lookup failed, so an empty result may be transient;
/// the empty state's Retry invalidates this provider to re-fetch.
final ownedGamesProvider = FutureProvider<List<int>>(
  (ref) async =>
      _orThrow(await ref.watch(gogStateProvider).getOwnedGames(), 'library'),
  retry: noRetry,
  name: 'ownedGamesProvider',
);

/// How many title lookups may be in flight at once. Phase 0 timed 9 titles at
/// 4.0 s serially and 0.55 to 1.8 s with 4 to 16 in flight: the calls are
/// latency-bound, so 8 is plenty.
const titleFetchConcurrency = 8;

final titleFetchLimiterProvider = Provider<AsyncLimiter>(
  (ref) => AsyncLimiter(titleFetchConcurrency),
  name: 'titleFetchLimiterProvider',
);

/// Every title read shares [titleFetchLimiterProvider], so a big library
/// resolves in parallel up to the bound and the grid fills in as each
/// arrives. A failure is an `AsyncError` for that game only and stays so
/// until [LibraryRefresher.refresh].
final gameTitleProvider = FutureProvider.family<String, int>(
  (ref, gameId) async {
    final gog = ref.watch(gogStateProvider);
    final title = await ref
        .watch(titleFetchLimiterProvider)
        .run(() => gog.getGameName(gameId));
    return _orThrow(title, 'title');
  },
  retry: noRetry,
  name: 'gameTitleProvider',
);

/// An empty summary isn't worth an error state, so [GogState] failures
/// resolve to `''`.
final gameSummaryProvider = FutureProvider.family<String, int>(
  (ref, gameId) => ref.watch(gogStateProvider).getGameSummary(gameId),
  retry: noRetry,
  name: 'gameSummaryProvider',
);

/// Failures resolve to an empty list, like [gameSummaryProvider].
final gameScreenshotsProvider = FutureProvider.family<List<String>, int>(
  (ref, gameId) => ref.watch(gogStateProvider).getGameScreenshots(gameId),
  retry: noRetry,
  name: 'gameScreenshotsProvider',
);

final gameBuildsProvider = FutureProvider.family<List<GameBuild>, int>(
  (ref, gameId) async =>
      _orThrow(await ref.watch(gogStateProvider).getBuilds(gameId), 'builds'),
  retry: noRetry,
  name: 'gameBuildsProvider',
);

typedef GameProductsKey = ({int gameId, String buildName});

final gameProductsProvider =
    FutureProvider.family<List<DownloadableProduct>, GameProductsKey>(
      (ref, key) async => _orThrow(
        await ref
            .watch(gogStateProvider)
            .getProducts(key.gameId, key.buildName),
        'products',
      ),
      retry: noRetry,
      name: 'gameProductsProvider',
    );

/// One page of Proton-GE releases (1-based). An empty page is the end of
/// the list; a failure is an `AsyncError`.
final protonReleasesProvider = FutureProvider.family<List<ProtonRelease>, int>(
  (ref, page) async => _orThrow(
    await ref.watch(gogStateProvider).getProtonReleases(page),
    'releases',
  ),
  retry: noRetry,
  name: 'protonReleasesProvider',
);

/// The library's Refresh. Clears the backend's cache,
/// then re-reads the owned list and any title that failed. Titles that
/// loaded are kept: they don't change, and refetching them is the slow part.
class LibraryRefresher {
  LibraryRefresher(this._ref);

  final Ref _ref;

  /// Returns false if the owned list couldn't be fetched; the previous list
  /// stays in `ownedGamesProvider`'s value.
  Future<bool> refresh() async {
    await _ref.read(gogStateProvider).clearCache();
    final owned = _ref.read(ownedGamesProvider).value ?? const <int>[];
    for (final id in owned) {
      if (_ref.read(gameTitleProvider(id)).hasError) {
        _ref.invalidate(gameTitleProvider(id));
      }
    }
    _ref.invalidate(ownedGamesProvider);
    try {
      await _ref.read(ownedGamesProvider.future);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final libraryRefresherProvider = Provider<LibraryRefresher>(
  LibraryRefresher.new,
  name: 'libraryRefresherProvider',
);

typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// One-shot title read for dialogs and install checks: the cached title, or
/// `null` if it can't be loaded.
///
/// Takes `ref.read`, so it works from both a `Ref` and a `WidgetRef`.
Future<String?> readGameTitle(ProviderReader read, int gameId) async {
  try {
    return await read(gameTitleProvider(gameId).future);
  } catch (_) {
    return null;
  }
}
