import 'dart:async';
import 'dart:collection';

/// Runs at most [maxConcurrent] async tasks at once; the rest wait their turn
/// in FIFO order.
///
/// GOG's per-game calls (titles) are latency-bound, so firing the whole
/// library at once gains nothing past a point and just floods the API.
class AsyncLimiter {
  AsyncLimiter(this.maxConcurrent) : assert(maxConcurrent > 0);

  final int maxConcurrent;
  int _running = 0;
  final Queue<Completer<void>> _waiting = Queue();

  Future<T> run<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final slot = Completer<void>();
      _waiting.add(slot);
      // The finishing task hands its slot over without decrementing.
      await slot.future;
    } else {
      _running++;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }
}
