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

  group('v1.1.1 — job-starting streams are never cached', () {
    test('verifyGameFiles hits the backend and returns a fresh stream every call', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);

      final first = state.verifyGameFiles(1, '/path', 'build', [1]);
      final second = state.verifyGameFiles(1, '/path', 'build', [1]);

      expect(backend.callsTo('verifyDownload'), hasLength(2));
      expect(identical(first, second), isFalse);
    });

    test('verifyGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()..throwOn['verifyDownload'] = Exception('boom');
      final state = await _state(backend);

      expect(state.verifyGameFiles(1, '/path', 'build', [1]), isNull);
    });

    test('repairGameFiles hits the backend and returns a fresh stream every call', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);

      final first = state.repairGameFiles(1, '/path', 'build', [1]);
      final second = state.repairGameFiles(1, '/path', 'build', [1]);

      expect(backend.callsTo('repairDownload'), hasLength(2));
      expect(identical(first, second), isFalse);
    });

    test('repairGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()..throwOn['repairDownload'] = Exception('boom');
      final state = await _state(backend);

      expect(state.repairGameFiles(1, '/path', 'build', [1]), isNull);
    });

    test('downloadGameFiles hits the backend and returns a fresh stream every call', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);

      final first = state.downloadGameFiles(1, '/path', 'build', [1]);
      final second = state.downloadGameFiles(1, '/path', 'build', [1]);

      expect(backend.callsTo('downloadGame'), hasLength(2));
      expect(identical(first, second), isFalse);
    });

    test('downloadGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()..throwOn['downloadGame'] = Exception('boom');
      final state = await _state(backend);

      expect(state.downloadGameFiles(1, '/path', 'build', [1]), isNull);
    });

    test(
      'downloadProtonRelease hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.downloadProtonRelease('tag', '/dir');
        final second = state.downloadProtonRelease('tag', '/dir');

        expect(backend.callsTo('downloadProtonRelease'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('downloadProtonRelease returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['downloadProtonRelease'] = Exception('boom');
      final state = await _state(backend);

      expect(state.downloadProtonRelease('tag', '/dir'), isNull);
    });

    test('downloadSaves hits the backend and returns a fresh stream every call', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);

      final first = state.downloadSaves(1, 'build', '/prefix', '/install');
      final second = state.downloadSaves(1, 'build', '/prefix', '/install');

      expect(backend.callsTo('downloadSaves'), hasLength(2));
      expect(identical(first, second), isFalse);
    });

    test('downloadSaves returns null on a thrown error', () async {
      final backend = FakeGogBackend()..throwOn['downloadSaves'] = Exception('boom');
      final state = await _state(backend);

      expect(state.downloadSaves(1, 'build', '/prefix', '/install'), isNull);
    });

    test('uploadSaves hits the backend and returns a fresh stream every call', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);

      final first = state.uploadSaves(1, 'build', '/prefix', '/install');
      final second = state.uploadSaves(1, 'build', '/prefix', '/install');

      expect(backend.callsTo('uploadSaves'), hasLength(2));
      expect(identical(first, second), isFalse);
    });

    test('uploadSaves returns null on a thrown error', () async {
      final backend = FakeGogBackend()..throwOn['uploadSaves'] = Exception('boom');
      final state = await _state(backend);

      expect(state.uploadSaves(1, 'build', '/prefix', '/install'), isNull);
    });
  });
}

Future<GogState> _state(FakeGogBackend backend) async =>
    (await createContainer(backend: backend)).read(gogStateProvider);
