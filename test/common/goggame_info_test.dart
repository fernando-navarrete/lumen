import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/goggame_info.dart';
import 'package:lumen/models/launch_target.dart';

// Trimmed copies of real goggame-<id>.info files collected in v1.2.0 Phase 0
// (fields the reader ignores, like `languages`, are mostly dropped).

const _witcher3Id = 1495134320;
const _witcher3 = {
  'gameId': '1495134320',
  'name': 'The Witcher 3: Wild Hunt - Game of the Year Edition',
  'playTasks': [
    {
      'additionalPaths': [
        {
          'path':
              r'<?APPLICATION_DATA_LOCAL?>\Programs\CD Projekt Red\REDlauncher',
          'type': 'filesystemPath',
        },
      ],
      'category': 'launcher',
      'isPrimary': true,
      'name': 'The Witcher® 3 - Wild Hunt',
      'path': 'REDprelauncher.exe',
      'type': 'FileTask',
    },
    {
      'arguments': '--launcher-fallback="DirectX 11"',
      'category': 'launcher',
      'name': 'The Witcher® 3 - Wild Hunt (DX11)',
      'path': 'REDprelauncher.exe',
      'type': 'FileTask',
    },
    {
      'category': 'game',
      'isHidden': true,
      'name': 'The Witcher® 3 - Wild Hunt',
      'path': 'bin/x64_dx12/witcher3.exe',
      'type': 'FileTask',
      'workingDir': 'bin/x64_dx12',
    },
    {
      'category': 'other',
      'link': 'http://www.gog.com/en/support/the_witcher_3_wild_hunt',
      'name': 'Support',
      'type': 'URLTask',
    },
    {
      'category': 'game',
      'isHidden': true,
      'name': 'The Witcher® 3 - Wild Hunt (DX11)',
      'path': 'bin/x64/witcher3.exe',
      'type': 'FileTask',
      'workingDir': 'bin/x64',
    },
  ],
  'rootGameId': '1495134320',
  'version': 1,
};
const _witcher3Files = [
  'REDprelauncher.exe',
  'bin/x64_dx12/witcher3.exe',
  'bin/x64/witcher3.exe',
];

const _cyberpunkId = 1423049311;
const _cyberpunk = {
  'gameId': '1423049311',
  'name': 'Cyberpunk 2077',
  'osBitness': ['64'],
  'playTasks': [
    {
      'category': 'launcher',
      'isPrimary': true,
      'name': 'Cyberpunk 2077',
      'path': 'REDprelauncher.exe',
      'type': 'FileTask',
    },
    {
      'category': 'game',
      'isHidden': true,
      'name': 'Cyberpunk 2077',
      'path': r'bin\x64\Cyberpunk2077.exe',
      'type': 'FileTask',
    },
  ],
  'rootGameId': '1423049311',
  'version': 1,
};

// A Cyberpunk 2077 DLC's .info, which sits next to the base game's.
const _cyberpunkDlcId = 1256837418;
const _cyberpunkDlc = {
  'gameId': '1256837418',
  'name': 'Cyberpunk 2077: Phantom Liberty',
  'playTasks': <Object>[],
  'rootGameId': '1423049311',
  'version': 1,
};

const _witcherEeId = 1207658924;
const _witcherEe = {
  'gameId': '1207658924',
  'name': "The Witcher Enhanced Edition Director's Cut",
  'playTasks': [
    {
      'category': 'launcher',
      'compatibilityFlags': 'DISABLEDWM HIGHDPIAWARE RUNASADMIN WIN7RTM',
      'isPrimary': true,
      'name': "The Witcher Enhanced Edition Director's Cut",
      'path': 'launcher.exe',
      'type': 'FileTask',
    },
    {
      'category': 'game',
      'isHidden': true,
      'name': "The Witcher Enhanced Edition Director's Cut",
      'path': r'System\witcher.exe',
      'type': 'FileTask',
      'workingDir': 'System',
    },
    {
      'category': 'document',
      'name': 'Manual',
      'path': 'Manual.pdf',
      'type': 'FileTask',
    },
    {
      'category': 'document',
      'link': 'http://www.gog.com/support/the_witcher',
      'name': 'Support',
      'type': 'URLTask',
    },
    {
      'arguments': '-dontForceMinReqs',
      'icon': 'goggame-1207658924.dll',
      'name': "The Witcher Enhanced Edition Director's Cut [Safe Mode]",
      'path': 'System//witcher.exe',
      'type': 'FileTask',
      'workingDir': 'System',
    },
  ],
  'rootGameId': '1207658924',
  'version': 1,
};

const _hellpointId = 1503950763;
const _hellpoint = {
  'gameId': '1503950763',
  'name': 'Hellpoint',
  'playTasks': [
    {
      'category': 'game',
      'isPrimary': true,
      'name': 'Hellpoint',
      'path': 'Hellpoint.exe',
      'type': 'FileTask',
    },
  ],
  'version': 1,
};

void main() {
  late Directory root;

  // Linux-only app (see CLAUDE.md), so '/' is always the separator.
  void touch(String relativePath) {
    final file = File('${root.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
  }

  void writeInfo(int id, Object json) {
    File(
      '${root.path}/goggame-$id.info',
    ).writeAsStringSync(const JsonEncoder.withIndent('    ').convert(json));
  }

  /// A minimal .info with the given tasks, for the synthetic cases.
  void writeTasks(int id, List<Map<String, Object>> tasks) =>
      writeInfo(id, {'gameId': '$id', 'playTasks': tasks});

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_goggame_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  group('readPrimaryPlayTask', () {
    test('a primary game task is used directly', () async {
      writeInfo(_hellpointId, _hellpoint);
      touch('Hellpoint.exe');

      expect(
        await readPrimaryPlayTask(root.path, _hellpointId),
        const LaunchTarget(
          executable: 'Hellpoint.exe',
          source: LaunchTargetSource.gogMetadata,
        ),
      );
    });

    test('a launcher primary loses to the hidden game task, whose '
        'backslash path is normalized', () async {
      writeInfo(_cyberpunkId, _cyberpunk);
      touch('REDprelauncher.exe');
      touch('bin/x64/Cyberpunk2077.exe');

      expect(
        await readPrimaryPlayTask(root.path, _cyberpunkId),
        const LaunchTarget(
          executable: 'bin/x64/Cyberpunk2077.exe',
          source: LaunchTargetSource.gogMetadata,
        ),
      );
    });

    test(
      'with two game tasks, the first one wins, with its workingDir',
      () async {
        writeInfo(_witcher3Id, _witcher3);
        _witcher3Files.forEach(touch);

        expect(
          await readPrimaryPlayTask(root.path, _witcher3Id),
          const LaunchTarget(
            executable: 'bin/x64_dx12/witcher3.exe',
            workingDir: 'bin/x64_dx12',
            source: LaunchTargetSource.gogMetadata,
          ),
        );
      },
    );

    test('the game task wins over a no-category task listed later', () async {
      writeInfo(_witcherEeId, _witcherEe);
      touch('launcher.exe');
      touch('System/witcher.exe');

      expect(
        await readPrimaryPlayTask(root.path, _witcherEeId),
        const LaunchTarget(
          executable: 'System/witcher.exe',
          workingDir: 'System',
          source: LaunchTargetSource.gogMetadata,
        ),
      );
    });

    test('a task with no category is never picked as the game', () async {
      writeTasks(1, [
        {
          'isPrimary': true,
          'category': 'launcher',
          'name': 'Launcher',
          'path': 'launcher.exe',
          'type': 'FileTask',
        },
        {
          'name': 'Safe mode',
          'path': 'game.exe',
          'arguments': '-safe',
          'type': 'FileTask',
        },
      ]);
      touch('launcher.exe');
      touch('game.exe');

      expect(
        (await readPrimaryPlayTask(root.path, 1))?.executable,
        'launcher.exe',
      );
    });

    test('with no isPrimary task, the first game task is used', () async {
      writeTasks(1, [
        {
          'category': 'tool',
          'name': 'Editor',
          'path': 'editor.exe',
          'type': 'FileTask',
        },
        {
          'category': 'game',
          'name': 'Game',
          'path': 'game.exe',
          'type': 'FileTask',
        },
      ]);
      touch('editor.exe');
      touch('game.exe');

      expect((await readPrimaryPlayTask(root.path, 1))?.executable, 'game.exe');
    });

    test('with no game task and no primary, gives null', () async {
      writeTasks(1, [
        {
          'category': 'tool',
          'name': 'Editor',
          'path': 'editor.exe',
          'type': 'FileTask',
        },
      ]);
      touch('editor.exe');

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('a missing game exe falls back to the launcher primary', () async {
      writeInfo(_cyberpunkId, _cyberpunk);
      touch('REDprelauncher.exe');

      expect(
        (await readPrimaryPlayTask(root.path, _cyberpunkId))?.executable,
        'REDprelauncher.exe',
      );
    });

    test('gives null when no listed exe exists on disk', () async {
      writeInfo(_cyberpunkId, _cyberpunk);
      touch('SomethingElse.exe');

      expect(await readPrimaryPlayTask(root.path, _cyberpunkId), isNull);
    });

    test('gives null for a URLTask-only .info', () async {
      writeTasks(1, [
        {
          'category': 'other',
          'isPrimary': true,
          'link': 'https://www.gog.com/',
          'name': 'Support',
          'type': 'URLTask',
        },
      ]);

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('ignores non-.exe FileTasks, even a primary game one', () async {
      writeTasks(1, [
        {
          'category': 'game',
          'isPrimary': true,
          'name': 'Manual',
          'path': 'Manual.pdf',
          'type': 'FileTask',
        },
      ]);
      touch('Manual.pdf');

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('reads only goggame-<gameId>.info, not a DLC or another '
        "product's file in the same dir", () async {
      writeInfo(_cyberpunkDlcId, _cyberpunkDlc);
      writeInfo(_witcherEeId, _witcherEe);
      touch('launcher.exe');
      touch('System/witcher.exe');

      expect(await readPrimaryPlayTask(root.path, _cyberpunkId), isNull);
      expect(await readPrimaryPlayTask(root.path, _cyberpunkDlcId), isNull);
    });

    test('gives null when there is no .info file', () async {
      touch('Game.exe');

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('gives null for a missing install dir', () async {
      expect(
        await readPrimaryPlayTask('${root.path}/does_not_exist', 1),
        isNull,
      );
    });

    test('gives null for corrupt JSON', () async {
      File('${root.path}/goggame-1.info').writeAsStringSync('{"playTasks": [');
      touch('game.exe');

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('gives null for valid JSON of the wrong shape', () async {
      File('${root.path}/goggame-1.info').writeAsStringSync('[1, 2]');

      expect(await readPrimaryPlayTask(root.path, 1), isNull);
    });

    test('strips a UTF-8 BOM', () async {
      File(
        '${root.path}/goggame-$_hellpointId.info',
      ).writeAsStringSync('﻿${jsonEncode(_hellpoint)}');
      touch('Hellpoint.exe');

      expect(
        (await readPrimaryPlayTask(root.path, _hellpointId))?.executable,
        'Hellpoint.exe',
      );
    });

    test('skips a task whose path escapes the install root', () async {
      // The install is a subdir, so the escaping targets really exist.
      final install = '${root.path}/install';
      Directory(install).createSync();
      touch('outside.exe');
      touch('elsewhere/x');
      File('$install/goggame-1.info').writeAsStringSync(
        jsonEncode({
          'playTasks': [
            {
              'category': 'game',
              'isPrimary': true,
              'name': 'Escape',
              'path': r'..\outside.exe',
              'type': 'FileTask',
            },
            {
              'category': 'game',
              'name': 'Game',
              'path': 'game.exe',
              'type': 'FileTask',
              'workingDir': '../elsewhere',
            },
            {
              'category': 'game',
              'name': 'Game 2',
              'path': 'game2.exe',
              'type': 'FileTask',
            },
          ],
        }),
      );
      touch('install/game.exe');
      touch('install/game2.exe');

      expect((await readPrimaryPlayTask(install, 1))?.executable, 'game2.exe');
    });

    test('an empty workingDir means the exe\'s parent', () async {
      writeTasks(1, [
        {
          'category': 'game',
          'isPrimary': true,
          'name': 'Game',
          'path': 'bin/game.exe',
          'type': 'FileTask',
          'workingDir': '',
        },
      ]);
      touch('bin/game.exe');

      expect((await readPrimaryPlayTask(root.path, 1))?.workingDir, isNull);
    });

    test('an arguments string that does not tokenize falls back to a '
        'whitespace split', () async {
      writeTasks(1, [
        {
          'category': 'game',
          'isPrimary': true,
          'name': 'Game',
          'path': 'game.exe',
          'type': 'FileTask',
          'arguments': ' -a  "unterminated b ',
        },
      ]);
      touch('game.exe');

      expect((await readPrimaryPlayTask(root.path, 1))?.arguments, [
        '-a',
        '"unterminated',
        'b',
      ]);
    });
  });

  group('listPlayTasks', () {
    test('lists every existing named exe task in file order, launchers '
        'included, with quoted arguments tokenized', () async {
      writeInfo(_witcher3Id, _witcher3);
      _witcher3Files.forEach(touch);

      final tasks = await listPlayTasks(root.path, _witcher3Id);

      expect(tasks.map((t) => t.name), [
        'The Witcher® 3 - Wild Hunt',
        'The Witcher® 3 - Wild Hunt (DX11)',
        'The Witcher® 3 - Wild Hunt',
        'The Witcher® 3 - Wild Hunt (DX11)',
      ]);
      expect(tasks.map((t) => t.target).toList(), const [
        LaunchTarget(
          executable: 'REDprelauncher.exe',
          source: LaunchTargetSource.gogMetadata,
        ),
        LaunchTarget(
          executable: 'REDprelauncher.exe',
          arguments: ['--launcher-fallback=DirectX 11'],
          source: LaunchTargetSource.gogMetadata,
        ),
        LaunchTarget(
          executable: 'bin/x64_dx12/witcher3.exe',
          workingDir: 'bin/x64_dx12',
          source: LaunchTargetSource.gogMetadata,
        ),
        LaunchTarget(
          executable: 'bin/x64/witcher3.exe',
          workingDir: 'bin/x64',
          source: LaunchTargetSource.gogMetadata,
        ),
      ]);
    });

    test('includes a no-category task, normalizing its // path, and skips '
        'documents, URLTasks and missing files', () async {
      writeInfo(_witcherEeId, _witcherEe);
      touch('launcher.exe');
      touch('System/witcher.exe');
      touch('Manual.pdf');

      final tasks = await listPlayTasks(root.path, _witcherEeId);

      expect(tasks.map((t) => t.target.executable), [
        'launcher.exe',
        'System/witcher.exe',
        'System/witcher.exe',
      ]);
      expect(
        tasks.last.name,
        "The Witcher Enhanced Edition Director's Cut [Safe Mode]",
      );
      expect(tasks.last.target.arguments, ['-dontForceMinReqs']);
      expect(tasks.last.target.workingDir, 'System');
    });

    test('skips an exe task with no name', () async {
      writeTasks(1, [
        {'category': 'game', 'path': 'game.exe', 'type': 'FileTask'},
      ]);
      touch('game.exe');

      expect(await listPlayTasks(root.path, 1), isEmpty);
    });

    test('gives an empty list for a DLC .info with no playTasks', () async {
      writeInfo(_cyberpunkDlcId, _cyberpunkDlc);

      expect(await listPlayTasks(root.path, _cyberpunkDlcId), isEmpty);
    });
  });
}
