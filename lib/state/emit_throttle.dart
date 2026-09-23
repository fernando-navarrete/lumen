import 'dart:async';

/// Buffers not-yet-flushed values keyed by [K], so a notifier can throttle
/// how often a stream of high-frequency events (byte-progress ticks) turns
/// into a full state replacement — each replacement triggers a rebuild of
/// everything watching the provider, and progress events can fire many
/// times per second.
///
/// [put] either flushes immediately, or — with `throttle: true` — flushes at
/// most once per [interval], with a trailing timer so the final value in a
/// burst is never dropped even if it arrives before the interval is up.
/// Terminal/status-transition values should be put with `throttle: false`
/// (the default) so they land immediately instead of waiting behind the
/// trailing timer.
///
/// Originally lifted out of `DownloadsNotifier` (the first notifier to need
/// this) so `ProtonNotifier` and `SavesNotifier` could reuse the same
/// buffering/timer logic instead of copying it.
class ThrottledTaskBuffer<K, T> {
  ThrottledTaskBuffer(
    this._flushCallback, {
    this.interval = const Duration(milliseconds: 100),
  });

  final void Function(Map<K, T> pending) _flushCallback;
  final Duration interval;

  final Map<K, T> _pending = {};
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _trailingTimer;

  /// The buffered value for [key], if there's one not yet flushed —
  /// otherwise null. Callers combine this with their own state map to find
  /// the value currently registered for [key].
  T? operator [](K key) => _pending[key];

  /// Buffers [value] under [key], then flushes ([throttle]: false) or
  /// schedules a throttled flush ([throttle]: true) — see the class doc.
  void put(K key, T value, {bool throttle = false}) {
    _pending[key] = value;
    throttle ? _flushThrottled() : flush();
  }

  void _flushThrottled() {
    final elapsed = DateTime.now().difference(_lastFlush);
    if (elapsed >= interval) {
      _lastFlush = DateTime.now();
      flush();
    } else {
      _trailingTimer ??= Timer(interval - elapsed, () {
        _trailingTimer = null;
        _lastFlush = DateTime.now();
        flush();
      });
    }
  }

  /// Cancels any trailing timer, hands the buffered values to the flush
  /// callback, and clears the buffer. Does not itself count as a "throttled
  /// flush" for [_lastFlush] bookkeeping — only [_flushThrottled] advances
  /// that clock, so an unthrottled flush (e.g. a terminal event) doesn't
  /// reset the throttle window for whatever comes after it.
  void flush() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
    if (_pending.isEmpty) {
      return;
    }
    final pending = Map<K, T>.of(_pending);
    _pending.clear();
    _flushCallback(pending);
  }

  /// Drops [key]'s buffered value, if any, without flushing it.
  void remove(K key) => _pending.remove(key);

  /// Drops every buffered value and cancels the trailing timer, without
  /// flushing.
  void clear() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
    _pending.clear();
  }

  /// Cancels the trailing timer. Call from the owning notifier's
  /// `ref.onDispose`.
  void dispose() {
    _trailingTimer?.cancel();
    _trailingTimer = null;
  }
}
