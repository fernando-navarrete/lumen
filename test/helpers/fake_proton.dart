import 'dart:io';

/// Creates [dir] (if needed) with an executable `proton` stub inside it, the
/// same shape `ProtonNotifier._load`'s on-disk check
/// (`isExecutableFile('$path/proton')`, lib/state/proton_state.dart) expects
/// a real install to have. Returns [dir], so callers can use it directly as
/// a `ProtonState.installed` path. Doesn't run the script — content doesn't
/// matter, only that it exists and is executable, same as
/// `executable_lookup_test.dart` and `launch_state_test.dart`'s
/// `writeFakeProton`.
String fakeProtonInstall(String dir) {
  Directory(dir).createSync(recursive: true);
  final script = File('$dir/proton')..writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
  Process.runSync('chmod', ['+x', script.path]);
  return dir;
}
