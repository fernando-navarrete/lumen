import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/emit_throttle.dart';

// Real Future.delayed waits rather than fake_async -- same choice made in
// bridge_stream_test.dart, and this only needs a 100ms interval so real
// waits stay fast.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  group('ThrottledTaskBuffer', () {
    test('an unthrottled put flushes synchronously', () {
      final flushed = <Map<String, int>>[];
      final buffer = ThrottledTaskBuffer<String, int>(flushed.add);

      buffer.put('a', 1);

      expect(flushed, [
        {'a': 1},
      ]);
      expect(buffer['a'], null);
    });

    test(
      'a burst of throttled puts collapses into one immediate flush plus '
      'one trailing flush carrying the last value',
      () async {
        final flushed = <Map<String, int>>[];
        final buffer = ThrottledTaskBuffer<String, int>(
          flushed.add,
          interval: const Duration(milliseconds: 100),
        );

        // The first put in a burst flushes immediately (nothing flushed
        // recently), and every put after it -- until the interval elapses
        // -- is buffered instead.
        buffer.put('a', 1, throttle: true);
        buffer.put('a', 2, throttle: true);
        buffer.put('a', 3, throttle: true);
        expect(flushed, [
          {'a': 1},
        ]);
        expect(buffer['a'], 3);

        await settle();

        // The trailing flush carries the last-buffered value (3), not the
        // middle one that got overwritten while still buffered.
        expect(flushed, [
          {'a': 1},
          {'a': 3},
        ]);
      },
    );

    test('flush() cancels the trailing timer', () async {
      final flushed = <Map<String, int>>[];
      final buffer = ThrottledTaskBuffer<String, int>(
        flushed.add,
        interval: const Duration(milliseconds: 100),
      );

      buffer.put('a', 1, throttle: true); // flushes immediately
      buffer.put('a', 2, throttle: true); // buffered, schedules a trailing flush
      buffer.flush(); // should flush {'a': 2} now and cancel the timer

      expect(flushed, [
        {'a': 1},
        {'a': 2},
      ]);

      await settle();

      // No extra flush from the (cancelled) trailing timer.
      expect(flushed, [
        {'a': 1},
        {'a': 2},
      ]);
    });

    test('remove drops a pending value without flushing it', () {
      final flushed = <Map<String, int>>[];
      final buffer = ThrottledTaskBuffer<String, int>(
        flushed.add,
        interval: const Duration(milliseconds: 100),
      );

      buffer.put('a', 1, throttle: true); // flushes immediately
      buffer.put('a', 2, throttle: true); // buffered
      buffer.remove('a');

      expect(buffer['a'], null);
      buffer.flush();
      // Nothing left to flush -- only the first immediate flush happened.
      expect(flushed, [
        {'a': 1},
      ]);
    });

    test('clear drops every pending value and cancels the timer', () async {
      final flushed = <Map<String, int>>[];
      final buffer = ThrottledTaskBuffer<String, int>(
        flushed.add,
        interval: const Duration(milliseconds: 100),
      );

      buffer.put('a', 1, throttle: true); // flushes immediately
      buffer.put('a', 2, throttle: true); // buffered, schedules a trailing flush
      buffer.clear();

      expect(buffer['a'], null);
      await settle();
      // The trailing flush never fires.
      expect(flushed, [
        {'a': 1},
      ]);
    });
  });
}
