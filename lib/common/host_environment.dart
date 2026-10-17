import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gog_error.dart';

/// What the AppImage runtime adds to its process's environment. Phase 0
/// measured it: `PATH`, `LD_LIBRARY_PATH` and `XDG_DATA_DIRS` are untouched.
const appImageRuntimeVariables = {'APPDIR', 'APPIMAGE', 'ARGV0', 'OWD'};

/// [environment] (default: the real one) as the host session had it, for
/// every process Lumen starts: unchanged outside an AppImage, else without
/// [appImageRuntimeVariables]. Returns a new map; [environment] isn't touched.
Map<String, String> hostEnvironment([Map<String, String>? environment]) {
  final result = Map<String, String>.of(environment ?? Platform.environment);
  if (result.containsKey('APPIMAGE')) {
    result.removeWhere((key, _) => appImageRuntimeVariables.contains(key));
  }
  return result;
}

/// Opens a file path or URL in the desktop's default handler; `false` if it
/// couldn't be opened.
typedef OpenExternally = Future<bool> Function(String target);

/// How long `xdg-open` may run before it counts as having opened the target:
/// some handlers stay in the foreground.
const _openGrace = Duration(seconds: 5);

/// `xdg-open` with [hostEnvironment], as a provider so tests can stand in
/// for the desktop. url_launcher opens through GIO inside Lumen's own
/// process, which can't be given a cleaned environment.
final openExternallyProvider = Provider<OpenExternally>(
  (ref) => (target) async {
    try {
      final process = await Process.start(
        'xdg-open',
        [target],
        environment: hostEnvironment(),
        includeParentEnvironment: false,
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      final code = await process.exitCode.timeout(
        _openGrace,
        onTimeout: () => 0,
      );
      return code == 0;
    } catch (e) {
      logGogError(e);
      return false;
    }
  },
  name: 'openExternallyProvider',
);
