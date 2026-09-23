import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
        releaseDate: '2026-01-01T00:00:00+0000',
        releaseDateTimestamp: 0,
      ),
    ];

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('1.2.3'), findsOneWidget);
    expect(backend.callsTo('getGameBuilds'), hasLength(2));
  });

  testWidgets(
    'v1.0.8: a getGameBuilds that resolves after the tab is disposed does not crash',
    (tester) async {
      final backend = _GatedFakeGogBackend()..builds[gameId] = [];

      await pumpApp(tester, const BuildsTab(gameId: gameId), backend: backend);
      await tester.pump(); // post-frame callback starts _loadBuilds, which awaits the gate

      // Unmount BuildsTab while its getBuilds() future is still pending.
      await tester.pumpWidget(const SizedBox.shrink());

      backend.gate.complete();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
