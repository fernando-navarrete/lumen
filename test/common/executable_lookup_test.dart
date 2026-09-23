import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/executable_lookup.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumen_exelookup_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  File writeExecutable(String path) {
    final file = File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\n');
    Process.runSync('chmod', ['+x', file.path]);
    return file;
  }

  group('isExecutableFile', () {
    test('true for an executable regular file', () {
      final file = writeExecutable('${root.path}/run.sh');
      expect(isExecutableFile(file.path), true);
    });

    test('false for a non-executable regular file', () {
      final file = File('${root.path}/plain.txt')
        ..writeAsStringSync('not executable');
      expect(isExecutableFile(file.path), false);
    });

    test('false for a directory, even one with the x bit set', () {
      final dir = Directory('${root.path}/subdir')..createSync();
      expect(isExecutableFile(dir.path), false);
    });

    test('false for a missing path', () {
      expect(isExecutableFile('${root.path}/missing'), false);
    });
  });

  group('resolveExecutable', () {
    test('a bare name resolves against the PATH entry containing it', () {
      final dirA = Directory('${root.path}/a')..createSync();
      final dirB = Directory('${root.path}/b')..createSync();
      writeExecutable('${dirB.path}/wrap');

      final resolved = resolveExecutable(
        'wrap',
        pathEnv: '${dirA.path}:${dirB.path}',
      );
      expect(resolved, '${dirB.path}/wrap');
    });

    test('a bare name picks the first PATH entry when several match', () {
      final dirA = Directory('${root.path}/a')..createSync();
      final dirB = Directory('${root.path}/b')..createSync();
      writeExecutable('${dirA.path}/wrap');
      writeExecutable('${dirB.path}/wrap');

      final resolved = resolveExecutable(
        'wrap',
        pathEnv: '${dirA.path}:${dirB.path}',
      );
      expect(resolved, '${dirA.path}/wrap');
    });

    test('empty PATH entries are skipped', () {
      final dir = Directory('${root.path}/only')..createSync();
      writeExecutable('${dir.path}/wrap');

      final resolved = resolveExecutable('wrap', pathEnv: '::${dir.path}::');
      expect(resolved, '${dir.path}/wrap');
    });

    test('a bare name not on PATH resolves to null', () {
      expect(resolveExecutable('wrap', pathEnv: root.path), null);
    });

    test('a null PATH resolves to null for a bare name', () {
      expect(resolveExecutable('wrap', pathEnv: null), null);
    });

    test('an existing, executable absolute path resolves to itself', () {
      final file = writeExecutable('${root.path}/wrap');
      expect(resolveExecutable(file.path, pathEnv: null), file.path);
    });

    test('a missing absolute path resolves to null', () {
      expect(resolveExecutable('${root.path}/missing', pathEnv: null), null);
    });

    test('a relative path with a slash resolves against cwd', () {
      final subdir = Directory('${root.path}/bin')..createSync();
      writeExecutable('${subdir.path}/wrap');

      final resolved = resolveExecutable(
        'bin/wrap',
        pathEnv: null,
        cwd: root.path,
      );
      expect(resolved, '${subdir.path}/wrap');
    });

    test('a path-containing name is never looked up on PATH', () {
      final pathDir = Directory('${root.path}/pathdir')..createSync();
      writeExecutable('${pathDir.path}/wrap');

      // "bin/wrap" contains a slash, so it's resolved against cwd (where it
      // doesn't exist) and never looked up on PATH, even though "wrap"
      // itself is on PATH.
      final resolved = resolveExecutable(
        'bin/wrap',
        pathEnv: pathDir.path,
        cwd: root.path,
      );
      expect(resolved, null);
    });
  });
}
