import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/keyring_error.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/account.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/gog_state.dart';
import 'package:lumen/state/home_state.dart';
import 'package:lumen/state/launch_state.dart';
import 'package:lumen/state/library_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/state/saves_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_secure_storage.dart';
import '../helpers/temp_data_home.dart';

class _RunningLaunchNotifier extends LaunchNotifier {
  @override
  LaunchState build() =>
      LaunchState({1: RunningGame(gameId: 1, status: LaunchStatus.running)});
}

class _RunningSavesNotifier extends SavesNotifier {
  @override
  SavesState build() =>
      SavesState({1: SaveTask(gameId: 1, direction: SaveDirection.upload)});
}

class _PausedDownloadsNotifier extends DownloadsNotifier {
  @override
  DownloadsState build() {
    super.build();
    return DownloadsState({
      1: ActivityTask(
        gameId: 1,
        kind: TaskKind.download,
        status: TaskStatus.paused,
      ),
    });
  }
}

void main() {
  late Directory dataHome;
  setUp(() => dataHome = useTempDataHome());

  late List<FakeGogBackend> backends;
  late FakeSecureStorage storage;

  Future<ProviderContainer> signedIn({
    List<Override> overrides = const [],
  }) async {
    backends = [];
    storage = FakeSecureStorage();
    await storage.write(key: 'auth', value: 'token');
    return createContainer(
      backendFactory: () {
        final b = FakeGogBackend()..ownedGames = [1, 2];
        backends.add(b);
        return b;
      },
      secureStorage: storage,
      overrides: overrides,
    );
  }

  test('deletes the token and resets backend, jobs and home state', () async {
    final container = await signedIn();
    await container.read(ownedGamesProvider.future);
    container.read(navBarItemProvider.notifier).select(NavBarItem.settings);
    container.read(librarySelectionProvider.notifier).select(1);
    container.read(librarySearchProvider.notifier).set('x');

    await container.read(accountProvider).signOut();

    expect(await storage.read(key: 'auth'), isNull);
    expect(backends.first.disposed, isTrue);
    expect(container.read(navBarItemProvider), NavBarItem.library);
    expect(container.read(librarySelectionProvider), isNull);
    expect(container.read(librarySearchProvider), '');

    // Metadata refetches against the new backend.
    await container.read(ownedGamesProvider.future);
    expect(backends, hasLength(2));
    expect(backends.first.callsTo('getOwnedGames'), hasLength(1));
    expect(backends.last.callsTo('getOwnedGames'), hasLength(1));
  });

  test('job notifiers talk to the new backend afterwards', () async {
    final container = await signedIn();
    container.read(downloadsStateProvider);
    await container.read(accountProvider).signOut();

    await container
        .read(downloadsStateProvider.notifier)
        .startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );

    expect(backends.first.callsTo('verifyDownload'), isEmpty);
    expect(backends.last.callsTo('verifyDownload'), hasLength(1));
    await backends.last.closeAll();
  });

  group('refuses while something is running', () {
    Future<void> expectRefused(
      ProviderContainer container,
      String mention,
    ) async {
      await expectLater(
        container.read(accountProvider).signOut(),
        throwsA(
          isA<SignOutError>().having((e) => '$e', 'message', contains(mention)),
        ),
      );
      expect(await storage.read(key: 'auth'), 'token');
      expect(backends.single.disposed, isFalse);
    }

    test('a verification', () async {
      final container = await signedIn();
      await container
          .read(downloadsStateProvider.notifier)
          .startVerification(
            1,
            path: '/games/foo',
            buildName: 'build-1',
            productIds: [1],
          );
      addTearDown(backends.single.closeAll);
      await expectRefused(container, 'a verification');
    });

    test('a Proton download', () async {
      final container = await signedIn();
      container.read(protonStateProvider);
      await container
          .read(protonStateProvider.notifier)
          .downloadRelease(
            const ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000),
            '${dataHome.path}/target',
          );
      addTearDown(backends.single.closeAll);
      await expectRefused(container, 'a Proton download');
    });

    test('a cloud save sync', () async {
      final container = await signedIn(
        overrides: [savesStateProvider.overrideWith(_RunningSavesNotifier.new)],
      );
      await expectRefused(container, 'a cloud save sync');
    });

    test('a running game', () async {
      final container = await signedIn(
        overrides: [
          launchStateProvider.overrideWith(_RunningLaunchNotifier.new),
        ],
      );
      await expectRefused(container, 'a running game');
    });
  });

  test('a paused download does not block', () async {
    final container = await signedIn(
      overrides: [
        downloadsStateProvider.overrideWith(_PausedDownloadsNotifier.new),
      ],
    );
    container.read(downloadsStateProvider);

    await container.read(accountProvider).signOut();

    expect(await storage.read(key: 'auth'), isNull);
  });

  test('a keyring failure leaves the session untouched', () async {
    final container = await signedIn();
    container.read(gogStateProvider);
    storage.throwOnNext = PlatformException(code: 'Libsecret error');

    await expectLater(
      container.read(accountProvider).signOut(),
      throwsA(isA<KeyringUnavailableError>()),
    );

    expect(await storage.read(key: 'auth'), 'token');
    expect(backends, hasLength(1));
    expect(backends.single.disposed, isFalse);
  });
}
