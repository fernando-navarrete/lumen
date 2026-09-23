import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/screens/home/pages/library/game_settings_tab.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/pump_app.dart';

void main() {
  const gameId = 1;

  // Launch-args field, identified by its hint text.
  Finder argsField() => find.widgetWithText(TextField, '-skipintro -windowed');

  // setLaunchArgs is a no-op for a game with no config, so every test starts
  // from a downloaded game with the given stored args.
  Map<String, Object> seededPrefs(List<String> launchArgs) => {
    'games': jsonEncode({
      'version': GamesNotifier.gamesSchemaVersion,
      'games': {
        '$gameId': {
          'status': 'downloaded',
          'selectedBuild': 'b1',
          'launchArgs': launchArgs,
        },
      },
    }),
  };

  group('GameSettingsTab launch arguments', () {
    testWidgets('quoted input persists as shell words', (tester) async {
      final container = await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: seededPrefs(const []),
      );

      await tester.enterText(argsField(), '"a b" c');
      await tester.pump();

      expect(container.read(gamesStateProvider).getLaunchArgs(gameId), [
        'a b',
        'c',
      ]);
    });

    testWidgets('stored words containing spaces show back quoted', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: seededPrefs(['a b', 'c']),
      );

      expect(tester.widget<TextField>(argsField()).controller!.text, "'a b' c");
    });

    testWidgets(
      'an unterminated quote shows an error without losing the saved args',
      (tester) async {
        final container = await pumpApp(
          tester,
          const GameSettingsTab(gameId: gameId),
          prefs: seededPrefs(const []),
        );

        await tester.enterText(argsField(), '-fps 60');
        await tester.pump();
        await tester.enterText(argsField(), '-fps "60');
        await tester.pump();

        expect(find.text('Unterminated double quote'), findsOneWidget);
        expect(container.read(gamesStateProvider).getLaunchArgs(gameId), [
          '-fps',
          '60',
        ]);

        await tester.enterText(argsField(), '-fps "60"');
        await tester.pump();

        expect(find.text('Unterminated double quote'), findsNothing);
        expect(container.read(gamesStateProvider).getLaunchArgs(gameId), [
          '-fps',
          '60',
        ]);
      },
    );
  });
}
