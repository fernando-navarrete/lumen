// Exercises the real SettingsPage widget: tapping the debug buttons must
// call through to GogState.clearAuth() / GamesState.clear() and confirm via
// a SnackBar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/screens/home/pages/settings_page.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:gogdl2_flutter_bridge/gogdl2_flutter_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Relies on Dart's noSuchMethod-based mocking: a concrete class implementing
// an all-abstract interface may leave members unimplemented as long as it
// overrides noSuchMethod. Nothing in this test calls through to the real
// Gog, so every member can safely fall back to it.
class _FakeGog implements Gog {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGogState extends GogState {
  _FakeGogState() : super(_FakeGog());

  bool clearAuthCalled = false;

  @override
  Future<void> clearAuth() async {
    clearAuthCalled = true;
  }

  // Stubbed defensively in case a test opens the "Manage / install
  // versions…" dialog, so that doesn't fall through to _FakeGog's
  // noSuchMethod throw.
  @override
  Future<List<ProtonRelease>?> getProtonReleases(int page) async => const [];
}

/// Provides a fixed initial [GamesState] synchronously, skipping the real
/// [GamesNotifier]'s async SharedPreferences load. Mutators are inherited
/// from the real notifier unchanged and operate on top of the fixed state.
class _FakeGamesNotifier extends GamesNotifier {
  _FakeGamesNotifier(this._initial);

  final GamesState _initial;

  @override
  GamesState build() => _initial;
}

void main() {
  const gameId = 7;

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester,
    GogState gogState,
    GamesState initialGamesState,
  ) async {
    final container = ProviderContainer(
      overrides: [
        gogStateProvider.overrideWithValue(gogState),
        gamesStateProvider.overrideWith(
          () => _FakeGamesNotifier(initialGamesState),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    return container;
  }

  testWidgets('clearing SharedPreferences wipes saved game config', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final initialGamesState = GamesState({
      gameId: GameConfig(
        status: GameStatus.notInstalled,
        selectedBuild: 'v1.0',
        productIds: {'base'},
      ),
    });

    final gogState = _FakeGogState();
    final container = await pumpSettings(tester, gogState, initialGamesState);

    await tester.tap(find.text('Clear SharedPreferences'));
    await tester.pumpAndSettle();

    final gamesState = container.read(gamesStateProvider);
    expect(gamesState.getSelectedBuild(gameId), isNull);
    expect(gamesState.getProductIds(gameId), isEmpty);
    expect(find.text('SharedPreferences cleared'), findsOneWidget);
  });

  testWidgets('clearing the auth token calls through to GogState', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gogState = _FakeGogState();

    await pumpSettings(tester, gogState, const GamesState.empty());

    await tester.tap(find.text('Clear auth token'));
    await tester.pumpAndSettle();

    expect(gogState.clearAuthCalled, isTrue);
    expect(find.text('Auth token cleared'), findsOneWidget);
  });
}
