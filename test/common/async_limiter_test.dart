import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/async_limiter.dart';

void main() {
  test(
    'never runs more than the bound at once, and runs all in order',
    () async {
      final limiter = AsyncLimiter(2);
      final gates = List.generate(5, (_) => Completer<void>());
      final started = <int>[];
      var running = 0;
      var peak = 0;

      final futures = [
        for (var i = 0; i < 5; i++)
          limiter.run(() async {
            started.add(i);
            peak = peak < ++running ? running : peak;
            await gates[i].future;
            running--;
            return i;
          }),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 1]);

      gates[0].complete();
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 1, 2]);

      for (final g in gates) {
        if (!g.isCompleted) g.complete();
      }
      expect(await Future.wait(futures), [0, 1, 2, 3, 4]);
      expect(started, [0, 1, 2, 3, 4]);
      expect(peak, 2);
    },
  );

  test('a throwing task frees its slot', () async {
    final limiter = AsyncLimiter(1);

    await expectLater(
      limiter.run<void>(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(await limiter.run(() async => 'ok'), 'ok');
  });
}
