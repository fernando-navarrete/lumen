import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/screens/home/pages/library/products_tab.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// v1.4.0 Phase 8: DLC on installed games is a pending selection applied
/// with a button; for a game that isn't installed toggles write the config.
void main() {
  const gameId = 1;

  String prefs(String status, List<int> ids) =>
      '{"version": 3, "games": {"1": {"status": "$status", '
      '"selectedBuild": "1.0", "installPath": "/games/foo", '
      '"pendingInstallPath": "/games/foo", '
      '"productIds": $ids}}}';

  FakeGogBackend backendWithDlc() =>
      FakeGogBackend()
        ..products[gameId] = const [
          DownloadableProduct(id: 1, name: 'Base', productType: 'GAME'),
          DownloadableProduct(id: 2, name: 'Soundtrack', productType: 'DLC'),
          DownloadableProduct(id: 3, name: 'Artbook', productType: 'DLC'),
        ];

  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  testWidgets('not installed: toggles write the config', (tester) async {
    final container = await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backendWithDlc(),
      prefs: {
        'games': prefs('notInstalled', [1]),
      },
    );
    await pumpFrames(tester);
    expect(
      find.text('Choose which DLC to install with the game'),
      findsOneWidget,
    );

    await tester.tap(find.text('Soundtrack'));
    await pumpFrames(tester);
    expect(container.read(gamesStateProvider).getProductIds(gameId), {1, 2});
    expect(find.text('Apply changes'), findsNothing);

    await tester.tap(find.text('Select all'));
    await pumpFrames(tester);
    expect(container.read(gamesStateProvider).getProductIds(gameId), {1, 2, 3});

    await tester.tap(find.text('Select none'));
    await pumpFrames(tester);
    expect(container.read(gamesStateProvider).getProductIds(gameId), {1});
  });

  testWidgets('a game with no DLC shows the empty state', (tester) async {
    final backend = FakeGogBackend()
      ..products[gameId] = const [
        DownloadableProduct(id: 1, name: 'Base', productType: 'GAME'),
      ];
    await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backend,
      prefs: {
        'games': prefs('notInstalled', [1]),
      },
    );
    await pumpFrames(tester);
    expect(find.text('This game has no DLC'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
  });

  testWidgets('installed: toggles are pending until applied or discarded', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backendWithDlc(),
      prefs: {
        'games': prefs('downloaded', [1, 3]),
      },
    );
    await pumpFrames(tester);

    await tester.tap(find.text('Soundtrack'));
    await pumpFrames(tester);
    await tester.tap(find.text('Artbook'));
    await pumpFrames(tester);
    expect(find.text('Install 1 DLC · Remove 1 DLC'), findsOneWidget);
    expect(container.read(gamesStateProvider).getProductIds(gameId), {1, 3});

    await tester.tap(find.text('Discard'));
    await pumpFrames(tester);
    expect(find.text('Apply changes'), findsNothing);

    await tester.tap(find.text('Select all'));
    await pumpFrames(tester);
    expect(find.text('Install 1 DLC'), findsOneWidget);
    await tester.tap(find.text('Select none'));
    await pumpFrames(tester);
    expect(find.text('Remove 1 DLC'), findsOneWidget);
  });

  testWidgets('applying an addition repairs with the larger set', (
    tester,
  ) async {
    final backend = backendWithDlc();
    await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backend,
      prefs: {
        'games': prefs('downloaded', [1]),
      },
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Soundtrack'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply changes'));
    await pumpFrames(tester);

    expect(backend.callsTo('removeProducts'), isEmpty);
    expect(
      backend.callsTo('repairDownload').single.args['selectedProducts'],
      unorderedEquals([1, 2]),
    );
    addTearDown(backend.closeAll);
  });

  testWidgets('applying a removal confirms, then calls removeProducts', (
    tester,
  ) async {
    final backend = backendWithDlc();
    await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backend,
      prefs: {
        'games': prefs('downloaded', [1, 2]),
      },
    );
    await pumpFrames(tester);
    await tester.tap(find.text('Soundtrack'));
    await pumpFrames(tester);
    await tester.tap(find.text('Apply changes'));
    await pumpFrames(tester);
    expect(find.text('Remove 1 DLC?'), findsOneWidget);
    expect(backend.callsTo('removeProducts'), isEmpty);

    await tester.tap(find.text('Remove'));
    await pumpFrames(tester);
    final call = backend.callsTo('removeProducts').single;
    expect(call.args['keep'], [1]);
    expect(call.args['remove'], [2]);
    expect(backend.callsTo('repairDownload'), isEmpty);
  });

  testWidgets('toggles are disabled while the game is downloading', (
    tester,
  ) async {
    final container = await pumpApp(
      tester,
      const ProductsTab(gameId: gameId),
      backend: backendWithDlc(),
      prefs: {
        'games': prefs('downloading', [1]),
      },
    );
    await pumpFrames(tester);
    expect(
      find.text('Finish or cancel the download to change DLC'),
      findsOneWidget,
    );
    await tester.tap(find.text('Soundtrack'));
    await pumpFrames(tester);
    expect(container.read(gamesStateProvider).getProductIds(gameId), {1});
    expect(find.text('Select all'), findsNothing);
  });
}
