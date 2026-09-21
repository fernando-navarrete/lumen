import 'package:flutter/foundation.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';

/// `GogError` is an opaque Rust handle with no `toString()` override, so
/// printing one gives `Instance of 'GogErrorImpl'`. Its `message()` is the
/// only way to the underlying gogdl-lib `Display` text.
String gogErrorText(Object error) =>
    error is GogError ? error.message() : error.toString();

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
