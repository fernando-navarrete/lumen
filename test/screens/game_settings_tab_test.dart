import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/launch_resolver.dart';
import 'package:lumen/models/launch_target.dart';
import 'package:lumen/screens/home/pages/library/game_settings_tab.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/pump_app.dart';
import '../helpers/temp_data_home.dart';

void main() {
  const gameId = 1;

  // The tab checks for the game's log under lumenDataDir().
  setUp(useTempDataHome);

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

  group('GameSettingsTab executable', () {
    const gogTask = LaunchTarget(
      executable: 'bin/game.exe',
      workingDir: 'bin',
      arguments: ['-task-arg'],
      source: LaunchTargetSource.gogMetadata,
    );

    Map<String, Object> installedPrefs({String? executable}) => {
      'games': jsonEncode({
        'version': GamesNotifier.gamesSchemaVersion,
        'games': {
          '$gameId': {
            'status': 'downloaded',
            'selectedBuild': 'b1',
            'installPath': '/games/foo',
            'executable': ?executable,
          },
        },
      }),
    };

    // Fakes every disk read, since the real scan runs on an isolate, which
    // never completes under testWidgets' fake async.
    Override fakeResolverWith({bool exeExists = true}) =>
        launchResolverProvider.overrideWith(
          (ref) => LaunchResolver(
            ref,
            scan: (_) async => const ['bin/game.exe', 'other.exe'],
            readPrimary: (_, _) async => gogTask,
            listTasks: (_, _) async => const [(name: 'Game', target: gogTask)],
            fileExists: (_) async => exeExists,
            dirExists: (_) async => true,
          ),
        );
    final fakeResolver = fakeResolverWith();

    testWidgets("with no override, shows what auto resolves to and the GOG "
        "task's arguments and working dir", (tester) async {
      await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: installedPrefs(),
        overrides: [fakeResolver],
      );
      await tester.pump();

      expect(find.text('Auto — bin/game.exe (from GOG)'), findsOneWidget);
      expect(find.text('Reset to auto'), findsNothing);
      expect(find.text('./game.exe -task-arg'), findsOneWidget);
      expect(find.text('(cwd: bin)'), findsOneWidget);
    });

    testWidgets('Reset to auto clears the override', (tester) async {
      final container = await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: installedPrefs(executable: 'other.exe'),
        overrides: [fakeResolver],
      );
      await tester.pump();

      expect(find.text('other.exe'), findsOneWidget);
      await tester.tap(find.text('Reset to auto'));
      await tester.pump();
      await tester.pump();

      expect(container.read(gamesStateProvider).getExecutable(gameId), isNull);
      expect(find.text('Auto — bin/game.exe (from GOG)'), findsOneWidget);
    });

    testWidgets('a missing override is marked, and not cleared', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: installedPrefs(executable: 'other.exe'),
        overrides: [fakeResolverWith(exeExists: false)],
      );
      await tester.pump();

      expect(find.text('other.exe — missing'), findsOneWidget);
      expect(
        find.text(
          'No longer in the install folder. Play will reset this to '
          'auto.',
        ),
        findsOneWidget,
      );
      expect(
        container.read(gamesStateProvider).getExecutable(gameId),
        'other.exe',
      );
    });

    testWidgets('Change lists GOG tasks first and saves the choice', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: installedPrefs(),
        overrides: [fakeResolver],
      );
      await tester.pump();

      await tester.tap(find.text('Change'));
      await tester.pump();
      await tester.pump();

      expect(find.text('GOG: Game'), findsOneWidget);
      await tester.tap(find.text('other.exe'));
      await tester.pump();
      await tester.tap(find.text('Use'));
      await tester.pump();

      expect(
        container.read(gamesStateProvider).getExecutable(gameId),
        'other.exe',
      );
    });
  });
  group('GameSettingsTab game log', () {
    TextButton openLogButton(WidgetTester tester) => tester.widget(
      find.ancestor(
        of: find.text('Open log'),
        matching: find.byType(TextButton),
      ),
    );

    testWidgets('Open log is disabled until the log exists', (tester) async {
      await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: seededPrefs(const []),
      );

      expect(find.text(gameLogPath(gameId)), findsOneWidget);
      expect(openLogButton(tester).onPressed, isNull);
    });

    testWidgets('Open log is enabled once the log exists', (tester) async {
      File(gameLogPath(gameId))
        ..createSync(recursive: true)
        ..writeAsStringSync('log');
      await pumpApp(
        tester,
        const GameSettingsTab(gameId: gameId),
        prefs: seededPrefs(const []),
      );

      expect(openLogButton(tester).onPressed, isNotNull);
    });
  });
}
