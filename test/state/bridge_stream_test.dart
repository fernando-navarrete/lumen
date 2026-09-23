import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/bridge_stream.dart';

// These tests drive real timers (`Future.delayed`) rather than
// `package:fake_async`'s virtual clock: `guardBridgeStream`'s `onCancel`
// returns the *inner* subscription's `cancel()` future, and that future's
// completion doesn't resolve within `fakeAsync`'s fake time — it only fires
// once the real event loop resumes, which defeats `fakeAsync.elapse`. The
// grace period (250ms) is short enough that real waits stay cheap here.
void main() {
  group('guardBridgeStream', () {
    test('forwards events and closes normally', () async {
      final inner = StreamController<int>();
      final events = <int>[];
      var done = false;
      Object? error;

      final outer = guardBridgeStream<int>(() => inner.stream);
      outer.listen(
        events.add,
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );

      inner.add(1);
      inner.add(2);
      await inner.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(events, [1, 2]);
      expect(done, isTrue);
      expect(error, isNull);
    });

    test(
      'an error thrown after onDone within the grace period arrives as a stream error',
      () async {
        final inner = StreamController<int>();
        var done = false;
        Object? error;

        final outer = guardBridgeStream<int>(() {
          // Simulates the discarded Rust `Result`'s error landing in the
          // guarded zone shortly after the stream's onDone fires.
          Timer(const Duration(milliseconds: 100), () {
            throw StateError('late');
          });
          return inner.stream;
        });
        outer.listen(
          (_) {},
          onError: (Object e) => error = e,
          onDone: () => done = true,
        );

        await inner.close();
        // Grace period hasn't elapsed yet (250ms), and the late error (at
        // 100ms) hasn't fired either.
        expect(done, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(error, isA<StateError>());
        expect(done, isTrue);
      },
    );

    test('an error after the grace period is dropped', () async {
      final inner = StreamController<int>();
      var done = false;
      Object? error;

      final outer = guardBridgeStream<int>(() {
        // Fires well after the 250ms grace period following onDone.
        Timer(const Duration(milliseconds: 400), () {
          throw StateError('too late');
        });
        return inner.stream;
      });
      outer.listen(
        (_) {},
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );

      await inner.close();
      // Past the grace period: the stream is already closed with no error.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(done, isTrue);
      expect(error, isNull);

      // The stray error at 400ms finds `finished` already true and is
      // swallowed rather than reopening or erroring the (closed) stream.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(error, isNull);
    });

    test('an in-band error closes the outer stream immediately', () async {
      final inner = StreamController<int>();
      var done = false;
      Object? error;

      final outer = guardBridgeStream<int>(() => inner.stream);
      outer.listen(
        (_) {},
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );

      inner.addError(Exception('bridge error'));
      await Future<void>.delayed(Duration.zero);

      expect(error, isNotNull);
      expect(done, isTrue);
    });

    test('cancelling the outer subscription cancels the inner one', () async {
      var innerCancelled = false;
      final inner = StreamController<int>(
        onCancel: () => innerCancelled = true,
      );

      final outer = guardBridgeStream<int>(() => inner.stream);
      final sub = outer.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      expect(innerCancelled, isTrue);
    });
  });
}
