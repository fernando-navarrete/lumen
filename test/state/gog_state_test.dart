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

  group('v1.0.10 — metadata getters fall back on a thrown error', () {
    // Debug and release builds must behave the same: none of these getters
    // is allowed to only special-case `GogError` (that was the bug) or to
    // only swallow the error in one build mode.
    test('getGameBackgroundLink returns empty', () async {
      final backend = FakeGogBackend()
        ..throwOn['getBackgroundImageLink'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getGameBackgroundLink(1), '');
    });

    test('getGameBoxartLink returns empty', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameBoxartLink'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getGameBoxartLink(1), '');
    });

    test('getGameSummary returns empty', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameSummary'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getGameSummary(1), '');
    });

    test('getGameScreenshots returns empty', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameScreenshots'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getGameScreenshots(1), isEmpty);
    });

    test('getBuilds returns null', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameBuilds'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getBuilds(1), isNull);
    });

    test('getGameName returns null', () async {
      final backend = FakeGogBackend()
        ..throwOn['getGameTitle'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getGameName(1), isNull);
    });
  });

  group('v1.0.11 — banner links are cached, not refetched on every call', () {
    test('getGameBackgroundLink hits the backend once for the same id', () async {
      final backend = FakeGogBackend()..backgroundLinks[1] = 'https://a/bg.jpg';
      final state = await _state(backend);

      await state.getGameBackgroundLink(1);
      await state.getGameBackgroundLink(1);

      expect(backend.callsTo('getBackgroundImageLink'), hasLength(1));
    });

    test('getGameBoxartLink hits the backend once for the same id', () async {
      final backend = FakeGogBackend()..boxartLinks[1] = 'https://a/box.jpg';
      final state = await _state(backend);

      await state.getGameBoxartLink(1);
      await state.getGameBoxartLink(1);

      expect(backend.callsTo('getGameBoxartLink'), hasLength(1));
    });
  });
}

Future<GogState> _state(FakeGogBackend backend) async =>
    (await createContainer(backend: backend)).read(gogStateProvider);
