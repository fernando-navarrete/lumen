import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    show DownloadGameProgress_Cancelled;
import 'package:lumen/common/keyring_error.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/state/gog_backend.dart' show JobCancel;
import 'package:lumen/state/gog_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_secure_storage.dart';

void main() {
  group('GogState.getOwnedGames', () {
    test('sorts the backend result (v1.0.6)', () async {
      final backend = FakeGogBackend()..ownedGames = [30, 10, 20];
      final container = await createContainer(backend: backend);

      final result = await container.read(gogStateProvider).getOwnedGames();

      expect(result, [10, 20, 30]);
    });

    test(
      'caches the sorted list — a second call hits the backend once',
      () async {
        final backend = FakeGogBackend()..ownedGames = [2, 1];
        final container = await createContainer(backend: backend);
        final state = container.read(gogStateProvider);

        await state.getOwnedGames();
        await state.getOwnedGames();

        expect(backend.callsTo('getOwnedGames'), hasLength(1));
      },
    );

    test(
      'an empty result is not cached, so a retry hits the backend again',
      () async {
        final backend = FakeGogBackend()..ownedGames = [];
        final container = await createContainer(backend: backend);
        final state = container.read(gogStateProvider);

        await state.getOwnedGames();
        await state.getOwnedGames();

        expect(backend.callsTo('getOwnedGames'), hasLength(2));
      },
    );

    test('a thrown error returns null and is not cached', () async {
      final backend = FakeGogBackend()
        ..throwOn['getOwnedGames'] = Exception('boom');
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

  test(
    'gogStateProvider resolves through gogBackendProvider with no native library',
    () async {
      final container = await createContainer();

      // If this reaches the fake instead of trying to dlopen the bridge, the
      // provider wiring (gogStateProvider -> gogBackendProvider) is correct.
      final result = await container.read(gogStateProvider).getOwnedGames();

      expect(result, isEmpty);
    },
  );

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

    test('getLoginUrl returns empty (v1.1.2)', () async {
      final backend = FakeGogBackend()
        ..throwOn['getLoginUrl'] = Exception('boom');
      final state = await _state(backend);

      expect(state.getLoginUrl(), '');
    });

    test('getProtonReleases returns null (v1.1.2)', () async {
      final backend = FakeGogBackend()
        ..throwOn['getProtonReleases'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getProtonReleases(1), isNull);
    });
  });

  group(
    'v1.1.2 — getProtonReleases distinguishes failure from end-of-list',
    () {
      test('an empty page returns an empty list, not null', () async {
        final backend = FakeGogBackend()..protonReleases = [];
        final state = await _state(backend);

        expect(await state.getProtonReleases(1), isEmpty);
      });
    },
  );

  group('v1.0.11 — banner links are cached, not refetched on every call', () {
    test(
      'getGameBackgroundLink hits the backend once for the same id',
      () async {
        final backend = FakeGogBackend()
          ..backgroundLinks[1] = 'https://a/bg.jpg';
        final state = await _state(backend);

        await state.getGameBackgroundLink(1);
        await state.getGameBackgroundLink(1);

        expect(backend.callsTo('getBackgroundImageLink'), hasLength(1));
      },
    );

    test('getGameBoxartLink hits the backend once for the same id', () async {
      final backend = FakeGogBackend()..boxartLinks[1] = 'https://a/box.jpg';
      final state = await _state(backend);

      await state.getGameBoxartLink(1);
      await state.getGameBoxartLink(1);

      expect(backend.callsTo('getGameBoxartLink'), hasLength(1));
    });
  });

  group('v1.3.0 — install size and free space', () {
    test(
      'getInstallSize forwards its arguments and returns the value',
      () async {
        final backend = FakeGogBackend()
          ..installSize = const InstallSize(downloadBytes: 10, diskBytes: 25);
        final state = await _state(backend);

        final size = await state.getInstallSize(7, 'build', [1, 2]);

        expect(size, const InstallSize(downloadBytes: 10, diskBytes: 25));
        final call = backend.callsTo('getInstallSize').single;
        expect(call.args['gameId'], 7);
        expect(call.args['buildName'], 'build');
        expect(call.args['selectedProducts'], [1, 2]);
      },
    );

    test('getInstallSize returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['getInstallSize'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getInstallSize(7, 'build', [1]), isNull);
    });

    test('getFreeSpace returns the value', () async {
      final backend = FakeGogBackend()..freeSpace = 1234;
      final state = await _state(backend);

      expect(await state.getFreeSpace('/games'), 1234);
      expect(backend.callsTo('getFreeSpace').single.args['path'], '/games');
    });

    test('getFreeSpace returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['getFreeSpace'] = Exception('boom');
      final state = await _state(backend);

      expect(await state.getFreeSpace('/games'), isNull);
    });
  });

  group('v1.3.0 — cancelling a job', () {
    test('ends the stream with Cancelled and no error', () async {
      final backend = FakeGogBackend();
      final state = await _state(backend);
      final cancel = JobCancel();
      final events = <Object?>[];
      var done = false;

      state
          .downloadGameFiles(1, '/path', 'build', [1], cancel: cancel)!
          .listen(events.add, onDone: () => done = true);
      expect(backend.jobCancel('downloadGame'), same(cancel));
      cancel.cancel();
      await pumpEventQueue();

      expect(events, hasLength(1));
      expect(events.single, isA<DownloadGameProgress_Cancelled>());
      expect(done, isTrue);
    });

    test('cancel is idempotent', () {
      final cancel = JobCancel();
      expect(cancel.isCancelled, isFalse);
      cancel
        ..cancel()
        ..cancel();
      expect(cancel.isCancelled, isTrue);
    });
  });

  group('v1.1.1 — job-starting streams are never cached', () {
    test(
      'verifyGameFiles hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.verifyGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());
        final second = state.verifyGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());

        expect(backend.callsTo('verifyDownload'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('verifyGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['verifyDownload'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.verifyGameFiles(1, '/path', 'build', [1], cancel: JobCancel()),
        isNull,
      );
    });

    test(
      'repairGameFiles hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.repairGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());
        final second = state.repairGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());

        expect(backend.callsTo('repairDownload'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('repairGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['repairDownload'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.repairGameFiles(1, '/path', 'build', [1], cancel: JobCancel()),
        isNull,
      );
    });

    test(
      'downloadGameFiles hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.downloadGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());
        final second = state.downloadGameFiles(1, '/path', 'build', [
          1,
        ], cancel: JobCancel());

        expect(backend.callsTo('downloadGame'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('downloadGameFiles returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['downloadGame'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.downloadGameFiles(1, '/path', 'build', [1], cancel: JobCancel()),
        isNull,
      );
    });

    test(
      'downloadProtonRelease hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.downloadProtonRelease(
          'tag',
          '/dir',
          cancel: JobCancel(),
        );
        final second = state.downloadProtonRelease(
          'tag',
          '/dir',
          cancel: JobCancel(),
        );

        expect(backend.callsTo('downloadProtonRelease'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('downloadProtonRelease returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['downloadProtonRelease'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.downloadProtonRelease('tag', '/dir', cancel: JobCancel()),
        isNull,
      );
    });

    test(
      'downloadSaves hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.downloadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        );
        final second = state.downloadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        );

        expect(backend.callsTo('downloadSaves'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('downloadSaves returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['downloadSaves'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.downloadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        ),
        isNull,
      );
    });

    test(
      'uploadSaves hits the backend and returns a fresh stream every call',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend);

        final first = state.uploadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        );
        final second = state.uploadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        );

        expect(backend.callsTo('uploadSaves'), hasLength(2));
        expect(identical(first, second), isFalse);
      },
    );

    test('uploadSaves returns null on a thrown error', () async {
      final backend = FakeGogBackend()
        ..throwOn['uploadSaves'] = Exception('boom');
      final state = await _state(backend);

      expect(
        state.uploadSaves(
          1,
          'build',
          '/prefix',
          '/install',
          cancel: JobCancel(),
        ),
        isNull,
      );
    });
  });

  group('v1.1.6 — secure storage', () {
    test(
      'loginWithCode writes to storage; restoreAuthFromStorage reads it back',
      () async {
        final backend = FakeGogBackend()..loginResult = 'auth-json';
        final storage = FakeSecureStorage();
        final state = await _state(backend, secureStorage: storage);

        await state.loginWithCode('code');
        final restored = await state.restoreAuthFromStorage();

        expect(restored, isTrue);
        expect(
          backend.callsTo('restoreAuth').single.args['token'],
          'auth-json',
        );
      },
    );

    test(
      'restoreAuthFromStorage returns false when nothing is stored',
      () async {
        final backend = FakeGogBackend();
        final state = await _state(backend, secureStorage: FakeSecureStorage());

        expect(await state.restoreAuthFromStorage(), isFalse);
        expect(backend.callsTo('restoreAuth'), isEmpty);
      },
    );

    test(
      'the token-refresh callback persists to the same storage key',
      () async {
        final backend = FakeGogBackend();
        final storage = FakeSecureStorage();
        final state = await _state(backend, secureStorage: storage);

        // Trigger callback registration.
        await state.restoreAuthFromStorage();
        await backend.onTokenRefresh!('refreshed-json');

        expect(await storage.read(key: 'auth'), 'refreshed-json');
      },
    );

    test('clearAuth deletes the stored token', () async {
      final backend = FakeGogBackend()..loginResult = 'auth-json';
      final storage = FakeSecureStorage();
      final state = await _state(backend, secureStorage: storage);
      await state.loginWithCode('code');

      await state.clearAuth();

      expect(await storage.read(key: 'auth'), isNull);
    });

    test(
      'a missing Secret Service surfaces a friendly KeyringUnavailableError',
      () async {
        final backend = FakeGogBackend();
        final storage = FakeSecureStorage()
          ..throwOnNext = PlatformException(
            code: 'Libsecret error',
            message: 'The name org.freedesktop.secrets was not provided',
          );
        final state = await _state(backend, secureStorage: storage);

        await expectLater(
          () => state.restoreAuthFromStorage(),
          throwsA(
            isA<KeyringUnavailableError>().having(
              (e) => e.message,
              'message',
              contains('No system keyring available'),
            ),
          ),
        );
      },
    );

    test(
      'a locked keyring surfaces a friendly KeyringUnavailableError',
      () async {
        final backend = FakeGogBackend()..loginResult = 'auth-json';
        final storage = FakeSecureStorage()
          ..throwOnNext = PlatformException(
            code: 'KeyringLocked',
            message: 'locked',
          );
        final state = await _state(backend, secureStorage: storage);

        await expectLater(
          () => state.loginWithCode('code'),
          throwsA(
            isA<KeyringUnavailableError>().having(
              (e) => e.message,
              'message',
              contains('locked'),
            ),
          ),
        );
      },
    );

    test('an unrelated PlatformException passes through unchanged', () async {
      final backend = FakeGogBackend()..loginResult = 'auth-json';
      final storage = FakeSecureStorage()
        ..throwOnNext = PlatformException(code: 'other_error', message: 'huh');
      final state = await _state(backend, secureStorage: storage);

      await expectLater(
        () => state.loginWithCode('code'),
        throwsA(isA<PlatformException>()),
      );
    });

    test(
      'a keyring failure in the refresh callback is logged, not thrown',
      () async {
        final backend = FakeGogBackend();
        final storage = FakeSecureStorage();
        final state = await _state(backend, secureStorage: storage);
        await state.restoreAuthFromStorage();

        storage.throwOnNext = PlatformException(
          code: 'Libsecret error',
          message: 'no keyring',
        );

        // Must not throw — GogBackend.setTokenRefreshCallback's contract is a
        // fire-and-forget notification, not something the bridge awaits/retries.
        await backend.onTokenRefresh!('refreshed-json');
      },
    );
  });
}

Future<GogState> _state(
  FakeGogBackend backend, {
  FakeSecureStorage? secureStorage,
}) async => (await createContainer(
  backend: backend,
  secureStorage: secureStorage,
)).read(gogStateProvider);
