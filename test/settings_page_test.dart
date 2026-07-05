// Exercises the real SettingsPage widget: tapping the debug buttons must
// call through to GogState.clearAuth() / GamesState.clear() and confirm via
// a SnackBar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl2_flutter/screens/home/pages/settings_page.dart';
import 'package:gogdl2_flutter/state/games_state.dart';
import 'package:gogdl2_flutter/state/gog_state.dart';
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
}

void main() {
  const gameId = 7;

  Future<void> pumpSettings(
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
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
  }

  testWidgets('clearing SharedPreferences wipes saved game config', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gamesState = GamesState();
    gamesState.setSelectedBuild(gameId, 'v1.0');
    gamesState.setProductIds(gameId, {'base'});

    final gogState = _FakeGogState();
    await pumpSettings(tester, gogState, gamesState);

    await tester.tap(find.text('Clear SharedPreferences'));
    await tester.pumpAndSettle();

    expect(gamesState.getSelectedBuild(gameId), isNull);
    expect(gamesState.getProductIds(gameId), isEmpty);
    expect(find.text('SharedPreferences cleared'), findsOneWidget);
  });

  testWidgets('clearing the auth token calls through to GogState', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gogState = _FakeGogState();
    final gamesState = GamesState();

    await pumpSettings(tester, gogState, gamesState);

    await tester.tap(find.text('Clear auth token'));
    await tester.pumpAndSettle();

    expect(gogState.clearAuthCalled, isTrue);
    expect(find.text('Auth token cleared'), findsOneWidget);
  });
}
