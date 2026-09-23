import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/app_paths.dart';

/// Points [lumenDataDir] (and everything derived from it — Proton prefixes,
/// the Proton install dir, the fake Steam compat client dir) at a fresh temp
/// directory for the duration of the current test, via
/// [xdgDataHomeOverride]. Registers `addTearDown` to reset the override and
/// recursively delete the temp dir, so tests never read or write under the
/// real `~/.local/share/lumen`.
Directory useTempDataHome() {
  final dir = Directory.systemTemp.createTempSync('lumen_test_data_home');
  xdgDataHomeOverride = dir.path;
  addTearDown(() {
    xdgDataHomeOverride = null;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return dir;
}
