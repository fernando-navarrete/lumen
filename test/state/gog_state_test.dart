import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/gog_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';

void main() {
  group('GogState.getOwnedGames', () {
    test('sorts the backend result (v1.0.6)', () async {
      final backend = FakeGogBackend()..ownedGames = [30, 10, 20];
      final container = await createContainer(backend: backend);

      final result = await container.read(gogStateProvider).getOwnedGames();

      expect(result, [10, 20, 30]);
    });

    test('caches the sorted list — a second call hits the backend once', () async {
      final backend = FakeGogBackend()..ownedGames = [2, 1];
      final container = await createContainer(backend: backend);
      final state = container.read(gogStateProvider);

      await state.getOwnedGames();
      await state.getOwnedGames();

      expect(backend.callsTo('getOwnedGames'), hasLength(1));
    });

    test('an empty result is not cached, so a retry hits the backend again', () async {
      final backend = FakeGogBackend()..ownedGames = [];
      final container = await createContainer(backend: backend);
      final state = container.read(gogStateProvider);

      await state.getOwnedGames();
      await state.getOwnedGames();

      expect(backend.callsTo('getOwnedGames'), hasLength(2));
    });

    test('a thrown error returns null and is not cached', () async {
      final backend = FakeGogBackend()..throwOn['getOwnedGames'] = Exception('boom');
      final container = await createContainer(backend: backend);
      final state = container.read(gogStateProvider);

      final result = await state.getOwnedGames();

      expect(result, isNull);
      expect(backend.callsTo('getOwnedGames'), hasLength(1));

      // Not cached: clearing the throw and retrying hits the backend again.
      backend.throwOn.clear();
      backend.ownedGames = [5];
      final retried = await state.getOwnedGames();

      expect(retried, [5]);
      expect(backend.callsTo('getOwnedGames'), hasLength(2));
    });

    test('invalidateOwnedGames forces a refetch', () async {
      final backend = FakeGogBackend()..ownedGames = [1];
      final container = await createContainer(backend: backend);
      final state = container.read(gogStateProvider);

      await state.getOwnedGames();
      state.invalidateOwnedGames();
      await state.getOwnedGames();

      expect(backend.callsTo('getOwnedGames'), hasLength(2));
    });
  });

  test('gogStateProvider resolves through gogBackendProvider with no native library', () async {
    final container = await createContainer();

    // If this reaches the fake instead of trying to dlopen the bridge, the
    // provider wiring (gogStateProvider -> gogBackendProvider) is correct.
    final result = await container.read(gogStateProvider).getOwnedGames();

    expect(result, isEmpty);
  });
}
