import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/directory_size.dart';

void main() {
  test('sums the files in a nested tree', () async {
    final dir = Directory.systemTemp.createTempSync('lumen_dir_size');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/a/b').createSync(recursive: true);
    File('${dir.path}/one').writeAsBytesSync(List.filled(10, 0));
    File('${dir.path}/a/b/two').writeAsBytesSync(List.filled(32, 0));

    expect(await directorySize(dir.path), 42);
  });

  test('returns null for a missing directory', () async {
    expect(await directorySize('/definitely/not/here'), isNull);
  });
}
