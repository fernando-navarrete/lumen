// Exercises GameHeader's preload behavior end-to-end through the real
// widget tree: builds/products are fetched, a default build+products are
// selected when nothing was saved, and the Install/Import buttons stay
// disabled until that preload completes.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl2_flutter/components/primary_button.dart';
import 'package:gogdl2_flutter/screens/home/pages/library/game_header.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGog implements Gog {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  @override
  Future<String> getBackgroundImageLink({required int gameId}) async => '';

  @override
  Future<List<DownloadableProduct>> getDownloadableProducts({
    required int gameId,
    required String buildName,
  }) async => [];

  @override
  Future<String> getGameBoxartLink({required int gameId}) async => '';

  @override
  Future<List<GameBuild>> getGameBuilds({required int gameId}) async => [];

  @override
  Future<List<String>> getGameScreenshots({required int gameId}) async => [];

  @override
  Future<String> getGameSummary({required int gameId}) async => '';

  @override
  Future<String> getGameTitle({required int gameId}) async => '';

  @override
  String getLoginUrl() => '';

  @override
  Future<Int32List> getOwnedGames() async => Int32List(0);

  @override
  Future<String> loginWithCode({required String code}) async => '';

  @override
  Future<void> refreshAuthWithCallback({
    required FutureOr<void> Function(String) callback,
  }) async {}

  @override
  Future<void> restoreAuthFromString({required String token}) async {}

  @override
  Stream<DownloadStream> downloadGame({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();

  @override
  Stream<RepairStream> repairDownload({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();

  @override
  Stream<VerificationStream> verifyDownload({
    required String path,
    required String buildName,
    required List<String> selectedProducts,
    required int gameId,
  }) => const Stream.empty();
}

class _FakeGameBuild implements GameBuild {
  _FakeGameBuild(this.versionName, this.releaseDateTimestamp);

  @override
  String buildId = '';

  @override
  String versionName;

  @override
  String releaseDate = '';

  @override
  int releaseDateTimestamp;

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _FakeProduct implements DownloadableProduct {
  _FakeProduct(this.id, this.name, this.productType);

  @override
  String id;

  @override
  String name;

  @override
  String productType;

  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

/// Stubs the two network calls GameHeader's preload makes; everything else
/// (getGameName/getGameBackgroundLink used by the always-on header UI)
/// falls back to the harmless empty-string defaults from _FakeGog.
class _FakeGogState extends GogState {
  _FakeGogState({this.builds, this.products}) : super(_FakeGog());

  final List<GameBuild>? builds;
  final List<DownloadableProduct>? products;
  final List<String> requestedProductBuilds = [];

  @override
  Future<String?> getGameName(int gameId) async => 'Test Game';

  @override
  Future<String> getGameBackgroundLink(int gameId) async => '';

  @override
  Future<List<GameBuild>?> getBuilds(int gameId) async => builds;

  @override
  Future<List<DownloadableProduct>?> getProducts(
    int gameId,
    String buildName,
  ) async {
    requestedProductBuilds.add(buildName);
    return products;
  }
}

bool _isButtonEnabled(WidgetTester tester, Finder buttonFinder) {
  final button = tester.widget<PrimaryButton>(buttonFinder);
  return button.enabled;
}

void main() {
  const gameId = 42;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpHeader(
    WidgetTester tester,
    GogState gogState,
    GamesState gamesState,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gogStateProvider.overrideWithValue(gogState),
          gamesStateProvider.overrideWithValue(gamesState),
        ],
        child: const MaterialApp(home: Scaffold(body: GameHeader(gameId: gameId))),
      ),
    );
  }

  testWidgets(
    'defaults to the latest build and all products when nothing is saved',
    (tester) async {
      // Explicitly typed as the bridge interface (not the fake subclass) —
      // List<E>.reduce is invariant in E at runtime, and the production
      // code's callback is typed for List<GameBuild>, matching how the
      // real bridge constructs its lists.
      final List<GameBuild> builds = [
        _FakeGameBuild('v1.0', 1000),
        _FakeGameBuild('v2.0', 3000), // latest
        _FakeGameBuild('v1.5', 2000),
      ];
      final List<DownloadableProduct> products = [
        _FakeProduct('base', 'Base Game', 'GAME'),
        _FakeProduct('dlc1', 'DLC One', 'DLC'),
        _FakeProduct('dlc2', 'DLC Two', 'DLC'),
      ];
      final gogState = _FakeGogState(builds: builds, products: products);
      final gamesState = GamesState();

      await pumpHeader(tester, gogState, gamesState);

      // Before the preload's async work resolves, both buttons are disabled.
      final installButton = find.byWidgetPredicate(
        (w) => w is PrimaryButton && w.glowing,
      );
      final importButton = find.byWidgetPredicate(
        (w) => w is PrimaryButton && !w.glowing,
      );
      expect(_isButtonEnabled(tester, installButton), isFalse);
      expect(_isButtonEnabled(tester, importButton), isFalse);

      // Let the post-frame callback and the awaited fetches complete.
      await tester.pumpAndSettle();

      expect(gamesState.getSelectedBuild(gameId), 'v2.0');
      expect(
        gamesState.getProductIds(gameId),
        {'base', 'dlc1', 'dlc2'},
      );
      expect(_isButtonEnabled(tester, installButton), isTrue);
      expect(_isButtonEnabled(tester, importButton), isTrue);
    },
  );

  testWidgets('keeps a previously saved build and product selection', (
    tester,
  ) async {
    final gamesState = GamesState();
    gamesState.setSelectedBuild(gameId, 'v1.0');
    gamesState.setProductIds(gameId, {'base'});

    final gogState = _FakeGogState(
      builds: <GameBuild>[_FakeGameBuild('v2.0', 9999)],
      products: <DownloadableProduct>[_FakeProduct('dlc1', 'DLC One', 'DLC')],
    );

    await pumpHeader(tester, gogState, gamesState);
    await tester.pumpAndSettle();

    // The saved build/products win; preload must not have re-fetched
    // products for a build that was already selected.
    expect(gamesState.getSelectedBuild(gameId), 'v1.0');
    expect(gamesState.getProductIds(gameId), {'base'});
    expect(gogState.requestedProductBuilds, isEmpty);

    final installButton = find.byWidgetPredicate(
      (w) => w is PrimaryButton && w.glowing,
    );
    expect(_isButtonEnabled(tester, installButton), isTrue);
  });
}
