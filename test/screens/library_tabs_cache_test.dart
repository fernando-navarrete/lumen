import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/screens/home/pages/library/builds_tab.dart';
import 'package:lumen/screens/home/pages/library/overview_tab.dart';
import 'package:lumen/screens/home/pages/library/products_tab.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// v1.4.0 Phase 1: metadata lives in providers, so leaving a tab and coming
/// back doesn't refetch it.
void main() {
  const gameId = 1;

  /// Pumps [tab] under a switch the test can flip to unmount and remount it,
  /// like leaving a game's tab and coming back.
  Future<ValueNotifier<bool>> pumpSwitchable(
    WidgetTester tester,
    Widget tab,
    FakeGogBackend backend, {
    Map<String, Object> prefs = const {},
  }) async {
    final shown = ValueNotifier(true);
    await pumpApp(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (_, show, _) => show ? tab : const SizedBox.shrink(),
      ),
      backend: backend,
      prefs: prefs,
    );
    return shown;
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('remounting the Overview tab does not refetch', (tester) async {
    final backend = FakeGogBackend()..summaries[gameId] = 'About this game';
    final shown = await pumpSwitchable(
      tester,
      const OverviewTab(gameId: gameId),
      backend,
    );
    await pumpFrames(tester);
    expect(find.text('About this game'), findsOneWidget);

    shown.value = false;
    await pumpFrames(tester);
    shown.value = true;
    await pumpFrames(tester);

    expect(find.text('About this game'), findsOneWidget);
    expect(backend.callsTo('getGameSummary'), hasLength(1));
    expect(backend.callsTo('getGameScreenshots'), hasLength(1));
  });

  testWidgets('remounting the Builds tab does not refetch', (tester) async {
    final backend = FakeGogBackend()
      ..builds[gameId] = [
        const GameBuild(
          buildId: '1',
          versionName: '1.0',
          releaseDateTimestamp: 1,
        ),
      ];
    final shown = await pumpSwitchable(
      tester,
      const BuildsTab(gameId: gameId),
      backend,
    );
    await pumpFrames(tester);
    expect(find.text('1.0'), findsOneWidget);

    shown.value = false;
    await pumpFrames(tester);
    shown.value = true;
    await pumpFrames(tester);

    expect(find.text('1.0'), findsOneWidget);
    expect(backend.callsTo('getGameBuilds'), hasLength(1));
  });

  testWidgets('the DLC tab shows an error with Retry, then the products', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getDownloadableProducts'] = Exception('boom');
    const json =
        '{"version": 3, "games": {"1": {"status": "notInstalled", '
        '"selectedBuild": "1.0", "productIds": []}}}';
    await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backend,
      prefs: {'games': json},
    );
    await pumpFrames(tester);
    expect(find.text("Couldn't load products."), findsOneWidget);

    backend.throwOn.clear();
    backend.products[gameId] = const [
      DownloadableProduct(id: 1, name: 'Base', productType: ProductType.game),
      DownloadableProduct(
        id: 2,
        name: 'Soundtrack',
        productType: ProductType.dlc,
      ),
    ];
    await tester.tap(find.text('Retry'));
    await pumpFrames(tester);

    expect(find.text('Soundtrack'), findsOneWidget);
    expect(find.text('Base'), findsNothing);
    expect(backend.callsTo('getDownloadableProducts'), hasLength(2));
  });
}
