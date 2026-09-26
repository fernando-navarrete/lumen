import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the user for a directory; `null` if they dismissed the picker.
typedef PickDirectory = Future<String?> Function();

/// The folder picker behind Install and Import, as a provider so widget
/// tests can stand in for the native `DirPicker` dialog.
final pickDirectoryProvider = Provider<PickDirectory>(
  (ref) =>
      () async => (await DirPicker.pick())?.uri?.toFilePath(),
  name: 'pickDirectoryProvider',
);
