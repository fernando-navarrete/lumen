import 'package:flutter/foundation.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/format.dart';
import 'package:lumen/common/keyring_error.dart';

/// `GogError` is an opaque Rust handle with no `toString()` override, so
/// printing one gives `Instance of 'GogErrorImpl'`. Its `message()` is the
/// only way to the underlying gogdl-lib `Display` text.
String gogErrorText(Object error) =>
    error is GogError ? error.message() : error.toString();

/// Text for a failed download, verification or repair, in Lumen's own words
/// for the kinds a user can act on. Anything else falls back to
/// [gogErrorText].
String jobErrorText(Object error) {
  if (error is! GogError) {
    return gogErrorText(error);
  }
  switch (error.kind()) {
    case GogErrorKind.notEnoughSpace:
      final shortfall = error.spaceShortfall();
      return shortfall == null
          ? 'Not enough disk space'
          : 'Not enough disk space: needs '
                '${formatBytes(shortfall.requiredBytes.toInt())}, only '
                '${formatBytes(shortfall.availableBytes.toInt())} free';
    case GogErrorKind.network:
      return 'Network error — check your connection and try again';
    case GogErrorKind.sessionExpired:
      return 'Your GOG session expired — sign in again';
    case GogErrorKind.notFound:
      return 'This build is no longer available from GOG';
    case GogErrorKind.integrity:
      return 'Downloaded data was corrupt — try again';
    case GogErrorKind.fileSystem:
      return "Couldn't write to the install folder — check that it's "
          'writable and its drive is mounted';
    case GogErrorKind.cloudSavesUnsupported:
    case GogErrorKind.invalidLoginCode:
    case GogErrorKind.unknown:
      return error.message();
  }
}

/// Text for a failed sign-in, shown inline under the code field.
String loginErrorText(Object error) {
  if (error is KeyringUnavailableError) {
    return error.message;
  }
  if (error is GogError) {
    return switch (error.kind()) {
      GogErrorKind.invalidLoginCode =>
        "GOG didn't accept that code. It may have expired — open the GOG "
            'login again and copy the new code.',
      GogErrorKind.network =>
        'Network error — check your connection and try again',
      _ => "Couldn't sign in: ${error.message()}",
    };
  }
  return "Couldn't sign in: ${gogErrorText(error)}";
}

/// Debug-only log for anything that came out of the bridge.
void logGogError(Object error, [StackTrace? stack]) {
  if (!kDebugMode) {
    return;
  }
  debugPrint(gogErrorText(error));
  if (stack != null) {
    debugPrint(stack.toString());
  }
}
