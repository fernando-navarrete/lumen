import 'dart:io';

import 'package:lumen/common/app_paths.dart';
import 'package:path/path.dart' as p;

/// Thrown by [deleteDirectoryGuarded] when it refuses to delete a path.
/// [toString] is the user-facing message, so it can go straight into a
/// snackbar.
class UnsafeDeleteError implements Exception {
  final String message;

  const UnsafeDeleteError(this.message);

  @override
  String toString() => message;
}

/// Recursively deletes the directory at [path], after refusing anything that
/// could take more than the caller meant to: an empty or relative path, a
/// symlink, a non-directory, `/`, `$HOME`, [lumenDataDir] itself, or any
/// ancestor of those. [purpose] names what's being deleted (e.g.
/// `Proton-GE X`) and is included in every refusal message.
///
/// A path that doesn't exist is a no-op, so callers can clean up a folder
/// that's already gone. Real I/O failures (`FileSystemException`) propagate
/// unchanged. Links *inside* the tree are removed without being followed.
Future<void> deleteDirectoryGuarded(
  String path, {
  required String purpose,
}) async {
  UnsafeDeleteError refuse(String reason) =>
      UnsafeDeleteError('Refusing to delete $path ($purpose): $reason');

  if (path.isEmpty || !p.isAbsolute(path)) {
    throw refuse('not an absolute path');
  }

  switch (FileSystemEntity.typeSync(path, followLinks: false)) {
    case FileSystemEntityType.notFound:
      return;
    case FileSystemEntityType.link:
      throw refuse('it is a symbolic link');
    case FileSystemEntityType.directory:
      break;
    default:
      throw refuse('it is not a directory');
  }

  final home = Platform.environment['HOME'];
  final roots = <(String, String)>[
    ('/', 'the filesystem root'),
    if (home != null && home.isNotEmpty) (home, 'your home folder'),
    (lumenDataDir(), "Lumen's data folder"),
  ];

  // Compare both the path as given and its symlink-resolved form, so a
  // symlinked parent component can't hide a protected root.
  final candidates = {
    p.normalize(path),
    Directory(path).resolveSymbolicLinksSync(),
  };
  for (final (root, name) in roots) {
    final rootForms = {p.normalize(root)};
    if (FileSystemEntity.typeSync(root) != FileSystemEntityType.notFound) {
      rootForms.add(Directory(root).resolveSymbolicLinksSync());
    }
    for (final candidate in candidates) {
      for (final rootForm in rootForms) {
        if (p.equals(candidate, rootForm)) {
          throw refuse('it is $name');
        }
        if (p.isWithin(candidate, rootForm)) {
          throw refuse('it contains $name');
        }
      }
    }
  }

  await Directory(path).delete(recursive: true);
}
