import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/common/safe_delete.dart';

import '../helpers/temp_data_home.dart';

void main() {
  late Directory dataHome;

  setUp(() {
    dataHome = useTempDataHome();
  });

  Future<void> expectRefused(String path) => expectLater(
    deleteDirectoryGuarded(path, purpose: 'test'),
    throwsA(isA<UnsafeDeleteError>()),
  );

  test('refuses /, \$HOME, lumenDataDir() and an ancestor of it', () async {
    Directory(lumenDataDir()).createSync(recursive: true);
    await expectRefused('/');
    await expectRefused(Platform.environment['HOME']!);
    await expectRefused(lumenDataDir());
    await expectRefused(dataHome.path);
    expect(Directory(lumenDataDir()).existsSync(), true);
  });

  test('refuses an empty or relative path', () async {
    await expectRefused('');
    await expectRefused('relative/dir');
  });

  test('refuses a symlink and leaves its target alone', () async {
    final target = Directory('${dataHome.path}/target')..createSync();
    File('${target.path}/keep').writeAsStringSync('x');
    final link = Link('${dataHome.path}/link')..createSync(target.path);
    await expectRefused(link.path);
    expect(File('${target.path}/keep').existsSync(), true);
  });

  test('refuses a file', () async {
    final file = File('${dataHome.path}/file')..writeAsStringSync('x');
    await expectRefused(file.path);
    expect(file.existsSync(), true);
  });

  test('deletes a nested directory', () async {
    final dir = Directory('${dataHome.path}/proton/GE-1/files/bin')
      ..createSync(recursive: true);
    File('${dir.path}/wine').writeAsStringSync('x');
    await deleteDirectoryGuarded(
      '${dataHome.path}/proton/GE-1',
      purpose: 'test',
    );
    expect(Directory('${dataHome.path}/proton/GE-1').existsSync(), false);
    expect(Directory('${dataHome.path}/proton').existsSync(), true);
  });

  test('a missing path is a no-op', () async {
    await deleteDirectoryGuarded('${dataHome.path}/nope', purpose: 'test');
  });

  test('a symlink inside the tree is removed, not followed', () async {
    final outside = Directory('${dataHome.path}/outside')..createSync();
    File('${outside.path}/keep').writeAsStringSync('x');
    final dir = Directory('${dataHome.path}/proton/GE-1')
      ..createSync(recursive: true);
    Link('${dir.path}/escape').createSync(outside.path);

    await deleteDirectoryGuarded(dir.path, purpose: 'test');

    expect(dir.existsSync(), false);
    expect(File('${outside.path}/keep').existsSync(), true);
  });
}
