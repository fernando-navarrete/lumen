import 'dart:async';

/// How long a closed bridge stream is held open waiting for a late error. The
/// stream's close and the Rust `Result` travel on different ports with no
/// ordering guarantee, and the close normally arrives first.
const _errorGrace = Duration(milliseconds: 250);

/// flutter_rust_bridge discards the Rust `Result` for stream APIs with
/// `unawaited`, so a failed job closes the stream normally and its `GogError`
/// escapes to the root zone. Starting the call inside its own zone catches
/// that error and re-injects it into the stream the app actually sees.
///
/// The returned stream is single-subscription, like the bridge's own.
Stream<T> guardBridgeStream<T>(Stream<T> Function() start) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? graceTimer;
  var finished = false;

  void finish([Object? error, StackTrace? stack]) {
    if (finished) {
      return;
    }
    finished = true;
    graceTimer?.cancel();
    if (error != null) {
      controller.addError(error, stack);
    }
    controller.close();
  }

  controller = StreamController<T>(
    onListen: () {
      runZonedGuarded(
        () {
          subscription = start().listen(
            controller.add,
            // Only reached if the bridge ever does deliver errors in-band.
            onError: (Object e, StackTrace s) => finish(e, s),
            onDone: () {
              graceTimer = Timer(_errorGrace, finish);
            },
          );
        },
        // The discarded Rust `Result` lands here, possibly after `onDone`.
        (error, stack) => finish(error, stack),
      );
    },
    onCancel: () {
      finished = true;
      graceTimer?.cancel();
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
