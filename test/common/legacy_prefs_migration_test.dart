import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/legacy_prefs_migration.dart';

import '../helpers/temp_data_home.dart';

void main() {
  late Directory home;

  File prefs(String appId) =>
      File('${home.path}/$appId/shared_preferences.json');

  void write(String appId, String content) {
    final file = prefs(appId);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  setUp(() => home = useTempDataHome());

  test('copies the legacy file and keeps the original', () async {
    write(legacyAppId, '{"flutter.games":"x"}');

    await migrateLegacyPreferences(dataHome: home.path);

    expect(prefs(lumenAppId).readAsStringSync(), '{"flutter.games":"x"}');
    expect(prefs(legacyAppId).existsSync(), isTrue);
  });

  test('does not overwrite an existing new file', () async {
    write(legacyAppId, 'old');
    write(lumenAppId, 'new');

    await migrateLegacyPreferences(dataHome: home.path);

    expect(prefs(lumenAppId).readAsStringSync(), 'new');
  });

  test('does nothing when there is no legacy file', () async {
    await migrateLegacyPreferences(dataHome: home.path);

    expect(Directory('${home.path}/$lumenAppId').existsSync(), isFalse);
  });

  test('lumenAppId matches the runner APPLICATION_ID', () {
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();

    expect(cmake, contains('set(APPLICATION_ID "$lumenAppId")'));
  });
}
