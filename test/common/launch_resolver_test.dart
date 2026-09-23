import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/launch_resolver.dart';
import 'package:lumen/models/launch_target.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/container.dart';

const _gameId = 42;

// A launcher primary plus a hidden game task with a working dir and
// arguments, the shape Phase 0 found on bigger titles.
const _info = {
  'gameId': '42',
  'playTasks': [
    {
      'category': 'launcher',
      'isPrimary': true,
      'name': 'Launcher',
      'path': 'launcher.exe',
      'type': 'FileTask',
    },
    {
      'arguments': '-dontForceMinReqs',
      'category': 'game',
      'isHidden': true,
      'name': 'The Game',
      'path': r'bin\x64\game.exe',
      'type': 'FileTask',
      'workingDir': 'bin',
    },
  ],
};

void main() {
  late Directory installDir;

  setUp(() {
    installDir = Directory.systemTemp.createTempSync('lumen_resolver_');
    addTearDown(() => installDir.deleteSync(recursive: true));
  });

  void writeFiles(List<String> paths) {
    for (final path in paths) {
      File('${installDir.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync('fake exe');
    }
  }

  void writeInfo() {
    File(
      '${installDir.path}/goggame-$_gameId.info',
    ).writeAsStringSync(jsonEncode(_info));
    writeFiles(['launcher.exe', 'bin/x64/game.exe']);
  }

  Future<(LaunchResolver, GamesState Function())> setUpResolver({
    String? executable,
  }) async {
    final container = await createContainer(
      prefs: {
        'games': jsonEncode({
          'version': GamesNotifier.gamesSchemaVersion,
          'games': {
            '$_gameId': {
              'status': 'downloaded',
              'selectedBuild': 'b1',
              'installPath': installDir.path,
              'executable': ?executable,
            },
          },
        }),
      },
    );
    return (
      container.read(launchResolverProvider),
      () => container.read(gamesStateProvider),
    );
  }

  Future<String?> failPick(List<String> candidates, {String? notice}) =>
      fail('picker should not be shown, got $candidates');

  test('a stored override wins over the .info', () async {
    writeInfo();
    writeFiles(['other.exe']);
    final (resolver, _) = await setUpResolver(executable: 'other.exe');

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: failPick,
    );

    expect(
      result.target,
      const LaunchTarget(
        executable: 'other.exe',
        source: LaunchTargetSource.userOverride,
      ),
    );
    expect(result.message, isNull);
  });

  test("an override matching a GOG task keeps that task's working dir and "
      'arguments', () async {
    writeInfo();
    final (resolver, _) = await setUpResolver(executable: 'bin/x64/game.exe');

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: failPick,
    );

    expect(
      result.target,
      const LaunchTarget(
        executable: 'bin/x64/game.exe',
        workingDir: 'bin',
        arguments: ['-dontForceMinReqs'],
        source: LaunchTargetSource.userOverride,
      ),
    );
  });

  test('no override + .info: the game play task, not persisted', () async {
    writeInfo();
    final (resolver, games) = await setUpResolver();

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: failPick,
    );

    expect(
      result.target,
      const LaunchTarget(
        executable: 'bin/x64/game.exe',
        workingDir: 'bin',
        arguments: ['-dontForceMinReqs'],
        source: LaunchTargetSource.gogMetadata,
      ),
    );
    expect(games().getExecutable(_gameId), isNull);
  });

  test('no .info + one exe: the scan result, not persisted', () async {
    writeFiles(['game.exe']);
    final (resolver, games) = await setUpResolver();

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: failPick,
    );

    expect(
      result.target,
      const LaunchTarget(
        executable: 'game.exe',
        source: LaunchTargetSource.scan,
      ),
    );
    expect(games().getExecutable(_gameId), isNull);
  });

  test('no .info + several exes: the picked one is persisted', () async {
    writeFiles(['a.exe', 'b.exe']);
    final (resolver, games) = await setUpResolver();
    List<String>? offered;

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: (candidates, {notice}) async {
        offered = candidates;
        return 'b.exe';
      },
    );

    expect(offered, ['a.exe', 'b.exe']);
    expect(
      result.target,
      const LaunchTarget(
        executable: 'b.exe',
        source: LaunchTargetSource.userOverride,
      ),
    );
    expect(games().getExecutable(_gameId), 'b.exe');
  });

  test('a canceled picker gives nothing and persists nothing', () async {
    writeFiles(['a.exe', 'b.exe']);
    final (resolver, games) = await setUpResolver();

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: (_, {notice}) async => null,
    );

    expect(result.target, isNull);
    expect(result.message, isNull);
    expect(games().getExecutable(_gameId), isNull);
  });

  test('no exes at all: a message and no target', () async {
    final (resolver, _) = await setUpResolver();

    final result = await resolver.resolve(
      _gameId,
      installDir.path,
      pick: failPick,
    );

    expect(result.target, isNull);
    expect(result.message, 'No launchable .exe found in ${installDir.path}');
  });

  group('stale override', () {
    const stale = '"gone.exe" is no longer in the install folder';

    test('is cleared, and the play task is used', () async {
      writeInfo();
      final (resolver, games) = await setUpResolver(executable: 'gone.exe');

      final result = await resolver.resolve(
        _gameId,
        installDir.path,
        pick: failPick,
      );

      expect(result.target?.executable, 'bin/x64/game.exe');
      expect(result.target?.source, LaunchTargetSource.gogMetadata);
      expect(result.message, '$stale — using bin/x64/game.exe instead');
      expect(games().getExecutable(_gameId), isNull);
    });

    test('is cleared, and a lone scan result is used', () async {
      writeFiles(['game.exe']);
      final (resolver, games) = await setUpResolver(executable: 'gone.exe');

      final result = await resolver.resolve(
        _gameId,
        installDir.path,
        pick: failPick,
      );

      expect(
        result.target,
        const LaunchTarget(
          executable: 'game.exe',
          source: LaunchTargetSource.scan,
        ),
      );
      expect(result.message, '$stale — using game.exe instead');
      expect(games().getExecutable(_gameId), isNull);
    });

    test(
      'with several scan results, offers the picker with a notice',
      () async {
        writeFiles(['a.exe', 'b.exe']);
        final (resolver, games) = await setUpResolver(executable: 'gone.exe');
        String? shownNotice;

        final result = await resolver.resolve(
          _gameId,
          installDir.path,
          pick: (candidates, {notice}) async {
            shownNotice = notice;
            return 'a.exe';
          },
        );

        expect(shownNotice, '$stale — choose another');
        expect(result.target?.executable, 'a.exe');
        expect(result.message, isNull);
        expect(games().getExecutable(_gameId), 'a.exe');
      },
    );

    test('with nothing else to launch: cleared, with a message', () async {
      final (resolver, games) = await setUpResolver(executable: 'gone.exe');

      final result = await resolver.resolve(
        _gameId,
        installDir.path,
        pick: failPick,
      );

      expect(result.target, isNull);
      expect(
        result.message,
        '$stale, and no other .exe was found in ${installDir.path}',
      );
      expect(games().getExecutable(_gameId), isNull);
    });
  });

  test('a missing install folder stops with a message and keeps the '
      'override', () async {
    final (resolver, games) = await setUpResolver(executable: 'game.exe');
    final gone = '${installDir.path}/gone';

    final result = await resolver.resolve(_gameId, gone, pick: failPick);

    expect(result.target, isNull);
    expect(result.message, 'The install folder $gone no longer exists');
    expect(games().getExecutable(_gameId), 'game.exe');
  });

  group('previewAuto', () {
    test(
      'reports the play task, one scan result, or a candidate count',
      () async {
        final (resolver, _) = await setUpResolver();

        expect(
          (await resolver.previewAuto(_gameId, installDir.path)).candidateCount,
          0,
        );

        writeFiles(['a.exe', 'b.exe']);
        final several = await resolver.previewAuto(_gameId, installDir.path);
        expect(several.target, isNull);
        expect(several.candidateCount, 2);

        writeInfo();
        final fromGog = await resolver.previewAuto(_gameId, installDir.path);
        expect(fromGog.target?.source, LaunchTargetSource.gogMetadata);
      },
    );
  });

  group('listCandidates', () {
    test(
      'lists GOG tasks first with labels, then unlisted scan results',
      () async {
        writeInfo();
        writeFiles(['extra.exe']);
        final (resolver, _) = await setUpResolver();

        final found = await resolver.listCandidates(_gameId, installDir.path);

        expect(found.candidates, [
          'launcher.exe',
          'bin/x64/game.exe',
          'extra.exe',
        ]);
        expect(found.labels, {
          'launcher.exe': 'GOG: Launcher',
          'bin/x64/game.exe': 'GOG: The Game',
        });
      },
    );
  });
}
