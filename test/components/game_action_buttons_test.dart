import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/launch_resolver.dart';
import 'package:lumen/components/game_action_buttons.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/launch_target.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/launch_state.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';
import '../helpers/temp_data_home.dart';

/// Records [launchGame] calls instead of spawning anything.
class _RecordingLaunchNotifier extends LaunchNotifier {
  final List<LaunchTarget> launched = [];

  @override
  Future<void> launchGame(
    int gameId, {
    required String protonPath,
    required String installPath,
    required LaunchTarget target,
    required String prefixPath,
    List<String> launchArgs = const [],
    Map<String, String> envVars = const {},
    List<String> launchWrapper = const [],
  }) async {
    launched.add(target);
  }
}

/// Starts with game [gameId] in [status] and records [stopGame] calls.
class _StatusLaunchNotifier extends LaunchNotifier {
  _StatusLaunchNotifier(this.gameId, this.status);

  final int gameId;
  final LaunchStatus status;
  final List<int> stopped = [];

  @override
  LaunchState build() =>
      LaunchState({gameId: RunningGame(gameId: gameId, status: status)});

  @override
  Future<void> stopGame(int gameId) async {
    stopped.add(gameId);
  }
}

/// Fails every launch straight away, as a spawn error would.
class _FailingLaunchNotifier extends LaunchNotifier {
  @override
  Future<void> launchGame(
    int gameId, {
    required String protonPath,
    required String installPath,
    required LaunchTarget target,
    required String prefixPath,
    List<String> launchArgs = const [],
    Map<String, String> envVars = const {},
    List<String> launchWrapper = const [],
  }) async {
    state = LaunchState({
      gameId: RunningGame(
        gameId: gameId,
        status: LaunchStatus.failed,
        error: 'Spawn failed',
      ),
    });
  }
}

/// Regression: an installed game whose saved build is empty, or no longer
/// listed by GOG, used to fail Verify immediately with no explanation (the
/// bridge looks builds up by name and throws on an unknown one). Verify now
/// checks the build first and explains the problem instead.
void main() {
  const gameId = 1;

  testWidgets(
    'Verify on an installed game with no selected build shows a message and '
    'starts nothing',
    (tester) async {
      final backend = FakeGogBackend();
      const json =
          '{"version": 1, "games": {"1": {"status": "downloaded", '
          '"selectedBuild": "", "productIds": [1], '
          '"installPath": "/games/foo"}}}';
      var selectBuildCalled = false;

      final container = await pumpApp(
        tester,
        GameActionButtons(
          gameId: gameId,
          onSelectBuild: () => selectBuildCalled = true,
        ),
        backend: backend,
        prefs: {'games': json},
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('No build selected for this game'),
        findsOneWidget,
      );
      expect(selectBuildCalled, isTrue);
      expect(container.read(downloadsStateProvider).tasks, isEmpty);
    },
  );

  testWidgets(
    'Verify on an installed game whose build is no longer listed shows a '
    'message and starts nothing',
    (tester) async {
      final backend = FakeGogBackend()..builds[gameId] = [];
      const json =
          '{"version": 1, "games": {"1": {"status": "downloaded", '
          '"selectedBuild": "delisted-build", "productIds": [1], '
          '"installPath": "/games/foo"}}}';
      var selectBuildCalled = false;

      final container = await pumpApp(
        tester,
        GameActionButtons(
          gameId: gameId,
          onSelectBuild: () => selectBuildCalled = true,
        ),
        backend: backend,
        prefs: {'games': json},
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump();

      expect(
        find.textContaining('is no longer offered by GOG'),
        findsOneWidget,
      );
      expect(selectBuildCalled, isTrue);
      expect(container.read(downloadsStateProvider).tasks, isEmpty);
    },
  );

  testWidgets(
    'an installed game with an empty selected build is not silently assigned '
    'the latest one',
    (tester) async {
      final backend = FakeGogBackend()
        ..builds[gameId] = [
          const GameBuild(
            buildId: 'b1',
            versionName: 'latest',
            releaseDate: '2026-02-01T00:00:00+0000',
            releaseDateTimestamp: 1,
          ),
        ];
      const json =
          '{"version": 1, "games": {"1": {"status": "downloaded", '
          '"selectedBuild": "", "productIds": [1], '
          '"installPath": "/games/foo"}}}';

      final container = await pumpApp(
        tester,
        const GameActionButtons(gameId: gameId),
        backend: backend,
        prefs: {'games': json},
      );
      await tester.pump();
      await tester.pump();

      expect(container.read(gamesStateProvider).getSelectedBuild(gameId), '');
    },
  );

  testWidgets(
    'a second Play tap while the first is still resolving is ignored',
    (tester) async {
      final gate = Completer<List<String>>();
      var scans = 0;
      final recorder = _RecordingLaunchNotifier();

      await pumpApp(
        tester,
        const GameActionButtons(gameId: gameId),
        prefs: {
          'games': jsonEncode({
            'version': GamesNotifier.gamesSchemaVersion,
            'games': {
              '$gameId': {
                'status': 'downloaded',
                'selectedBuild': 'b1',
                'productIds': [1],
                'installPath': '/games/foo',
                // Already set, so ensureProtonPrefix doesn't touch disk.
                'protonPrefixPath': '/games/prefix',
              },
            },
          }),
          'protonInstalled': jsonEncode({'GE-1': '/proton/GE-1'}),
          'protonDefault': 'GE-1',
        },
        overrides: [
          launchStateProvider.overrideWith(() => recorder),
          launchResolverProvider.overrideWith(
            (ref) => LaunchResolver(
              ref,
              scan: (_) {
                scans++;
                return gate.future;
              },
              readPrimary: (_, _) async => null,
              listTasks: (_, _) async => const [],
              fileExists: (_) async => true,
              dirExists: (_) async => true,
            ),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(find.text('Resolving…'), findsOneWidget);
      await tester.tap(find.text('Resolving…'), warnIfMissed: false);
      await tester.pump();

      gate.complete(['game.exe']);
      await tester.pump();
      await tester.pump();

      expect(scans, 1);
      expect(recorder.launched, [
        const LaunchTarget(
          executable: 'game.exe',
          source: LaunchTargetSource.scan,
        ),
      ]);
      expect(find.text('Play'), findsOneWidget);
    },
  );

  testWidgets(
    'Play with a missing override clears it and explains why in the picker',
    (tester) async {
      final recorder = _RecordingLaunchNotifier();

      final container = await pumpApp(
        tester,
        const GameActionButtons(gameId: gameId),
        prefs: {
          'games': jsonEncode({
            'version': GamesNotifier.gamesSchemaVersion,
            'games': {
              '$gameId': {
                'status': 'downloaded',
                'selectedBuild': 'b1',
                'productIds': [1],
                'installPath': '/games/foo',
                'executable': 'old.exe',
                'protonPrefixPath': '/games/prefix',
              },
            },
          }),
          'protonInstalled': jsonEncode({'GE-1': '/proton/GE-1'}),
          'protonDefault': 'GE-1',
        },
        overrides: [
          launchStateProvider.overrideWith(() => recorder),
          launchResolverProvider.overrideWith(
            (ref) => LaunchResolver(
              ref,
              scan: (_) async => const ['a.exe', 'b.exe'],
              readPrimary: (_, _) async => null,
              listTasks: (_, _) async => const [],
              fileExists: (_) async => false,
              dirExists: (_) async => true,
            ),
          ),
        ],
      );
      await tester.pump();

      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(
          '"old.exe" is no longer in the install folder — choose another',
        ),
        findsOneWidget,
      );
      expect(container.read(gamesStateProvider).getExecutable(gameId), isNull);
      expect(recorder.launched, isEmpty);
    },
  );
  group('launch-failure snackbar', () {
    Future<void> playAndFail(WidgetTester tester) async {
      await pumpApp(
        tester,
        const GameActionButtons(gameId: gameId),
        prefs: {
          'games': jsonEncode({
            'version': GamesNotifier.gamesSchemaVersion,
            'games': {
              '$gameId': {
                'status': 'downloaded',
                'selectedBuild': 'b1',
                'productIds': [1],
                'installPath': '/games/foo',
                'protonPrefixPath': '/games/prefix',
              },
            },
          }),
          'protonInstalled': jsonEncode({'GE-1': '/proton/GE-1'}),
          'protonDefault': 'GE-1',
        },
        overrides: [
          launchStateProvider.overrideWith(_FailingLaunchNotifier.new),
          launchResolverProvider.overrideWith(
            (ref) => LaunchResolver(
              ref,
              scan: (_) async => const [],
              readPrimary: (_, _) async => const LaunchTarget(
                executable: 'game.exe',
                source: LaunchTargetSource.gogMetadata,
              ),
              listTasks: (_, _) async => const [],
              fileExists: (_) async => true,
              dirExists: (_) async => true,
            ),
          ),
        ],
      );
      await tester.pump();
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('offers Open log when the launch wrote a log', (tester) async {
      useTempDataHome();
      File(gameLogPath(gameId))
        ..createSync(recursive: true)
        ..writeAsStringSync('log');

      await playAndFail(tester);

      expect(find.text('Spawn failed'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Open log'), findsOneWidget);
    });

    testWidgets('has no Open log action without a log', (tester) async {
      useTempDataHome();

      await playAndFail(tester);

      expect(find.text('Spawn failed'), findsOneWidget);
      expect(find.text('Open log'), findsNothing);
    });
  });

  group('Stop', () {
    Future<_StatusLaunchNotifier> pumpWithStatus(
      WidgetTester tester,
      LaunchStatus status,
    ) async {
      final notifier = _StatusLaunchNotifier(gameId, status);
      await pumpApp(
        tester,
        const GameActionButtons(gameId: gameId),
        prefs: {
          'games': jsonEncode({
            'version': GamesNotifier.gamesSchemaVersion,
            'games': {
              '$gameId': {
                'status': 'downloaded',
                'selectedBuild': 'b1',
                'productIds': [1],
                'installPath': '/games/foo',
              },
            },
          }),
        },
        overrides: [launchStateProvider.overrideWith(() => notifier)],
      );
      await tester.pump();
      return notifier;
    }

    testWidgets('a running game shows Stop, which calls stopGame', (
      tester,
    ) async {
      final notifier = await pumpWithStatus(tester, LaunchStatus.running);

      expect(find.text('Play'), findsNothing);
      await tester.tap(find.text('Stop'));
      await tester.pump();

      expect(notifier.stopped, [gameId]);
    });

    testWidgets('a stopping game shows a disabled Stopping…', (tester) async {
      final notifier = await pumpWithStatus(tester, LaunchStatus.stopping);

      await tester.tap(find.text('Stopping…'), warnIfMissed: false);
      await tester.pump();

      expect(notifier.stopped, isEmpty);
    });

    testWidgets('a launching game shows a disabled Launching…', (tester) async {
      final notifier = await pumpWithStatus(tester, LaunchStatus.launching);

      expect(find.text('Launching…'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      await tester.tap(find.text('Launching…'), warnIfMissed: false);
      await tester.pump();

      expect(notifier.stopped, isEmpty);
    });
  });
}
