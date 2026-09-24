import 'dart:io';
import 'dart:isolate';

/// Total size in bytes of the regular files under [path] (symlinks are not
/// followed), computed in an isolate so a big tree doesn't block the UI.
/// Returns `null` if the tree can't be read.
Future<int?> directorySize(String path) async {
  try {
    return await Isolate.run(() {
      var total = 0;
      for (final entity in Directory(
        path,
      ).listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
      return total;
    });
  } catch (_) {
    return null;
  }
}
