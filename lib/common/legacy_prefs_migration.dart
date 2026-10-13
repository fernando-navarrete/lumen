import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumen/common/app_paths.dart';

/// The GTK application ID (`APPLICATION_ID` in `linux/CMakeLists.txt`).
/// `shared_preferences_linux` keeps its file under `<data home>/<this>/`.
const lumenAppId = 'io.github.fernando_navarrete.Lumen';

/// The application ID before `v1.5.0`.
const legacyAppId = 'io.github.fernandonr189.lumen';

const _prefsFile = 'shared_preferences.json';

/// Copies the pre-`v1.5.0` SharedPreferences file to the directory the new
/// [lumenAppId] reads, when the new one doesn't exist yet. Copies rather than
/// moves, so going back to an older release still finds its data. Never
/// throws: a failure is logged and the app starts with empty preferences.
///
/// The keyring token is not carried over (its schema also names the app ID),
/// so users sign in once more.
Future<void> migrateLegacyPreferences({String? dataHome}) async {
  try {
    final base = dataHome ?? xdgDataHome();
    final legacy = File('$base/$legacyAppId/$_prefsFile');
    final current = File('$base/$lumenAppId/$_prefsFile');
    if (await current.exists() || !await legacy.exists()) return;
    await current.parent.create(recursive: true);
    await legacy.copy(current.path);
  } catch (e) {
    debugPrint('Legacy preferences migration failed: $e');
  }
}
