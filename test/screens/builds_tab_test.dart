import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart' show RepairGameProgress;
import 'package:lumen/components/side_column_layout.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/screens/home/pages/library/builds_tab.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// A [FakeGogBackend] whose [getGameBuilds] doesn't resolve until [gate] is
/// completed, so a test can unmount the widget mid-fetch.
class _GatedFakeGogBackend extends FakeGogBackend {
  final gate = Completer<void>();

  @override
  Future<List<GameBuild>> getGameBuilds(int gameId) async {
    await gate.future;
    return super.getGameBuilds(gameId);
  }
}

/// Regression `v1.0.7`: the Builds tab shows an error/empty state with a
/// Retry instead of crashing when fetching builds fails.
void main() {
  const gameId = 1;

  testWidgets('a failed getGameBuilds shows an error message, no crash', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getGameBuilds'] = Exception('boom');

    await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load builds."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty build list shows an empty-state message', (
    tester,
  ) async {
    final backend = FakeGogBackend()..builds[gameId] = [];

    await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text('No builds available.'), findsOneWidget);
  });

  testWidgets('the Refresh chip clears the backend cache, then refetches', (
    tester,
  ) async {
    final backend = FakeGogBackend()..builds[gameId] = const [];

    await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
    await tester.pump();
    await tester.pump();
    backend.calls.clear();

    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump();

    expect(backend.calls.map((c) => c.method).toList(), [
      'clearCache',
      'getGameBuilds',
    ]);
  });

  testWidgets('tapping Retry after clearing the failure lists the builds', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getGameBuilds'] = Exception('boom');

    await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't load builds."), findsOneWidget);

    backend.throwOn.clear();
    backend.builds[gameId] = [
      const GameBuild(
        buildId: 'b1',
        versionName: '1.2.3',
        releaseDateTimestamp: 0,
      ),
    ];

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('1970-01-01'), findsOneWidget);
    expect(backend.callsTo('getGameBuilds'), hasLength(2));
  });

  testWidgets(
    'an installed game whose saved build is no longer listed shows a stale-build note '
    'and no build is Active',
    (tester) async {
      final backend = FakeGogBackend()
        ..builds[gameId] = [
          const GameBuild(
            buildId: 'b2',
            versionName: '2.0.0',
            releaseDateTimestamp: 1,
          ),
        ];
      const json =
          '{"version": 1, "games": {"1": {"status": "downloaded", '
          '"selectedBuild": "1.0.0-delisted", "productIds": [1]}}}';

      await pumpApp(
        tester,
        const BuildsTab(gameId: gameId),
        backend: backend,
        prefs: {'games': json},
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining(
          'Installed build "1.0.0-delisted" is no longer listed',
        ),
        findsOneWidget,
      );
      expect(find.text('Active'), findsNothing);
    },
  );

  testWidgets(
    'v1.0.8: a getGameBuilds that resolves after the tab is disposed does not crash',
    (tester) async {
      final backend = _GatedFakeGogBackend()..builds[gameId] = [];

      await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
      await tester
          .pump(); // post-frame callback starts _loadBuilds, which awaits the gate

      // Unmount BuildsTab while its getBuilds() future is still pending.
      await tester.pumpWidget(const SizedBox.shrink());

      backend.gate.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an installed game on an older build is offered Update; the build is '
    'recorded only once the repair finishes',
    (tester) async {
      final backend = FakeGogBackend()
        ..builds[gameId] = [
          const GameBuild(
            buildId: 'b2',
            versionName: '2.0.0',
            releaseDateTimestamp: 2,
          ),
          const GameBuild(
            buildId: 'b1',
            versionName: '1.0.0',
            releaseDateTimestamp: 1,
          ),
        ];
      const json =
          '{"version": 1, "games": {"1": {"status": "downloaded", '
          '"selectedBuild": "1.0.0", "installPath": "/games/foo", '
          '"productIds": [1]}}}';

      await pumpApp(
        tester,
        const BuildsTab(gameId: gameId),
        backend: backend,
        prefs: {'games': json},
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      await tester.tap(find.text('Update'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Update to 2.0.0?'), findsOneWidget);
      await tester.tap(find.text('Update').last);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final repair = backend.callsTo('repairDownload').single;
      expect(repair.args['buildName'], '2.0.0');
      // Still on 1.0.0 (its row is the Active one) while the repair runs.
      expect(find.text('Update'), findsOneWidget);

      final controller = backend.repairController(gameId);
      controller.add(const RepairGameProgress.finished());
      unawaited(controller.close());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Update'), findsNothing);
      expect(find.text('Active'), findsOneWidget);
    },
  );

  group('side column', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      await pumpApp(
        tester,
        const BuildsTab(gameId: 1),
        backend: FakeGogBackend(),
        surfaceSize: Size(width, 900),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is hidden in a narrow tab', (tester) async {
      await pumpAt(tester, 560);
      expect(find.byKey(SideColumnLayout.sideKey), findsNothing);
    });

    testWidgets('is 280 wide in a medium tab', (tester) async {
      await pumpAt(tester, 1000);
      expect(tester.getSize(find.byKey(SideColumnLayout.sideKey)).width, 280);
    });

    testWidgets('is 340 wide in a wide tab', (tester) async {
      await pumpAt(tester, 1600);
      expect(tester.getSize(find.byKey(SideColumnLayout.sideKey)).width, 340);
    });
  });
}
