import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/executable_finder.dart';

void main() {
  late Directory root;

  // Linux-only app (see CLAUDE.md), so '/' is always the separator.
  void touch(String relativePath) {
    final file = File('${root.path}/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('');
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_exe_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  group('findExecutables', () {
    test(
      'finds real launch candidates and skips installers/redistributables',
      () {
        touch('Game.exe');
        touch('bin/x64/Game64.exe');
        touch('LAUNCHER.EXE'); // extension check is case-insensitive
        touch('readme.txt');
        touch('unins000.exe');
        touch('setup.exe');
        touch('__support/app/foo.exe');
        touch('_CommonRedist/vcredist_x64.exe');
        touch('DirectX/dxsetup.exe');

        final result = findExecutables(root.path);

        // Sorted by code unit, so uppercase ('G', 'L') sorts before lowercase
        // ('b').
        expect(result, ['Game.exe', 'LAUNCHER.EXE', 'bin/x64/Game64.exe']);
      },
    );

    test('returns an empty list for a missing directory', () {
      final missing = '${root.path}/does_not_exist';

      expect(findExecutables(missing), isEmpty);
    });

    // Known false negatives of the current substring heuristic — recorded as
    // characterization tests of existing behavior. Fixing these properly is
    // the ROADMAP v1.2.0 item: resolving executables from a game's
    // goggame-<id>.info `playTasks` instead of this scan.
    group('known false negatives (current heuristic, see ROADMAP v1.2.0)', () {
      test('a legitimate exe containing "crash" is skipped', () {
        touch('CrashDay.exe');

        expect(findExecutables(root.path), isEmpty);
      });

      test('a legitimate exe containing "report" is skipped', () {
        touch('Reporter.exe');

        expect(findExecutables(root.path), isEmpty);
      });

      test('a legitimate exe containing "install" is skipped', () {
        touch('InstallationGuide.exe');

        expect(findExecutables(root.path), isEmpty);
      });

      test(
        'a legitimate exe under a directory containing "support" is skipped',
        () {
          // The directory skip-list matches the whole relative path
          // (filename included), so a game whose own folder name merely
          // contains "support" loses everything under it, not just an
          // actual support/redist subfolder.
          touch('SupportiveGame/Game.exe');

          expect(findExecutables(root.path), isEmpty);
        },
      );
    });
  });
}
