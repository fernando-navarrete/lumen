import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';

/// The notifier throttles progress emits to ~10Hz with a trailing flush (see
/// `DownloadsNotifier._emitThrottle`). Tests wait past that window before
/// asserting on a value that arrived via a throttled emit, so they keep
/// passing unchanged once Phase 5 makes tasks immutable (the throttle then
/// gates a state *replacement* instead of a mutation, but the timing is the
/// same).
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  group('DownloadsNotifier — download', () {
    test('stage transitions and progress', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);
      // setGameStatus() no-ops without an existing GameConfig, so seed one —
      // otherwise the downloading assertion below would pass trivially.
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.downloadController(1);

      controller.add(
        DownloadGameProgress.started(
          totalFiles: BigInt.from(4),
          totalBytes: BigInt.from(1000),
        ),
      );
      await settle();
      var task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.stage, 'checkingFiles');
      expect(task.totalFiles, 4);
      expect(task.totalBytes, 1000);
      expect(games().getGameStatus(1), GameStatus.downloading);

      controller.add(
        DownloadGameProgress.fileSizeVerification(checkedFiles: BigInt.from(2)),
      );
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.processedFiles, 2);
      expect(task.progress, 2 / 4);

      controller.add(
        DownloadGameProgress.fileAllocationStarted(
          totalFiles: BigInt.from(4),
          totalBytes: BigInt.from(1000),
        ),
      );
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.stage, 'allocating');
      expect(task.processedFiles, 0);

      controller.add(
        DownloadGameProgress.fileAllocation(
          allocatedFiles: BigInt.from(3),
          allocatedBytes: BigInt.from(750),
        ),
      );
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.processedFiles, 3);

      controller.add(
        DownloadGameProgress.downloadProgress(downloadedBytes: BigInt.from(400)),
      );
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.stage, 'downloading');
      expect(task.downloadedBytes, 400);
      expect(task.progress, 400 / 1000);
    });

    test('finished + close marks the task completed and the game installed', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);

      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.downloadController(1);
      controller.add(const DownloadGameProgress.finished());
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.completed);
      expect(games().getGameStatus(1), GameStatus.downloaded);
      expect(games().getInstallPath(1), '/games/foo');
    });

    test(
      'v1.0.5: a download that finishes with allocation errorFiles is not marked installed',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);
        container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.downloadController(1);
        controller.add(const DownloadGameProgress.allocationError('bad.dat'));
        controller.add(const DownloadGameProgress.finished());
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.failed);
        expect(task.errorFiles, ['bad.dat']);
        expect(games().getGameStatus(1), GameStatus.notInstalled);
      },
    );

    test('closed without finished marks the task failed', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.downloadController(1);
      controller.add(
        DownloadGameProgress.downloadProgress(downloadedBytes: BigInt.from(10)),
      );
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(games().getGameStatus(1), GameStatus.notInstalled);
    });

    test('a thrown error starting the stream fails the task immediately', () async {
      final backend = FakeGogBackend()
        ..throwOn['downloadGame'] = Exception('boom');
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(games().getGameStatus(1), GameStatus.notInstalled);
    });

    test(
      'a running download blocks a re-start; a failed one is retried with a fresh stream',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        expect(backend.callsTo('downloadGame'), hasLength(1));

        final firstController = backend.downloadController(1);
        await firstController.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[1]!.status,
          TaskStatus.failed,
        );

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        expect(backend.callsTo('downloadGame'), hasLength(2));

        final secondController = backend.downloadController(1);
        secondController.add(const DownloadGameProgress.finished());
        await secondController.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[1]!.status,
          TaskStatus.completed,
        );
      },
    );
  });

  group('DownloadsNotifier — verification', () {
    test('byte progress', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.verifyController(1);

      controller.add(VerifyDownloadProgress.started(BigInt.from(1000)));
      await settle();
      var task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.stage, 'verifying');
      expect(task.totalBytes, 1000);

      controller.add(VerifyDownloadProgress.progress(BigInt.from(400)));
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.progress, 0.4);
    });

    test(
      'missing/corrupt/unreadable events fill verifyFailures and errorFiles',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.verifyController(1);

        controller.add(
          VerifyDownloadProgress.fileNotFound('missing.dat', BigInt.zero),
        );
        controller.add(
          VerifyDownloadProgress.checksumMismatch('corrupt.dat', BigInt.zero),
        );
        controller.add(
          VerifyDownloadProgress.couldNotResolvePath('bad-path.dat', BigInt.zero),
        );
        controller.add(VerifyDownloadProgress.finished(BigInt.from(3)));
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.verifyFailures['missing.dat'], VerifyFailure.missing);
        expect(task.verifyFailures['corrupt.dat'], VerifyFailure.corrupt);
        expect(
          task.verifyFailures['bad-path.dat'],
          VerifyFailure.unreadable,
        );
        expect(
          task.errorFiles,
          unorderedEquals(['missing.dat', 'corrupt.dat', 'bad-path.dat']),
        );
        expect(task.verifyFailureCount(VerifyFailure.missing), 1);
        expect(task.verifyFailureCount(VerifyFailure.corrupt), 1);
        expect(task.verifyFailureCount(VerifyFailure.unreadable), 1);
        expect(task.status, TaskStatus.failed);
        expect(task.chunksToRedownload, 3);
        expect(games().getInstallPath(1), isNull);
      },
    );

    test('a clean run completes and marks the game installed', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.verifyController(1);
      controller.add(VerifyDownloadProgress.finished(BigInt.zero));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.completed);
      expect(games().getGameStatus(1), GameStatus.downloaded);
      expect(games().getInstallPath(1), '/games/foo');
    });

    test(
      'v1.0.3: re-running Import after a failed Import dequeues the old task '
      'and starts a fresh stream',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        // A still-running verification blocks a second start.
        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        expect(backend.callsTo('verifyDownload'), hasLength(1));

        final firstController = backend.verifyController(1);
        firstController.add(
          VerifyDownloadProgress.fileNotFound('missing.dat', BigInt.zero),
        );
        firstController.add(VerifyDownloadProgress.finished(BigInt.from(1)));
        await firstController.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[1]!.status,
          TaskStatus.failed,
        );

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        expect(backend.callsTo('verifyDownload'), hasLength(2));
        // The new task starts clean, with no stale verifyFailures.
        expect(
          container.read(downloadsStateProvider).tasks[1]!.verifyFailures,
          isEmpty,
        );

        final secondController = backend.verifyController(1);
        secondController.add(VerifyDownloadProgress.finished(BigInt.zero));
        await secondController.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[1]!.status,
          TaskStatus.completed,
        );
      },
    );
  });

  group('DownloadsNotifier — repair', () {
    test(
      'damaged-file events land in verifyFailures, errorFiles stays empty, and '
      'a clean finish completes the task and installs the game',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);

        await notifier.startRepairForInstalled(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.repairController(1);

        controller.add(
          RepairGameProgress.fileNotFound('missing.dat', BigInt.zero),
        );
        controller.add(
          RepairGameProgress.checksumMismatch('corrupt.dat', BigInt.zero),
        );
        await settle();
        var task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.verifyFailures.keys, unorderedEquals(['missing.dat', 'corrupt.dat']));
        expect(task.errorFiles, isEmpty);

        controller.add(
          RepairGameProgress.verification(checkedBytes: BigInt.from(100)),
        );
        await settle();
        task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.stage, 'verifyingChunks');

        controller.add(
          RepairGameProgress.downloadStarted(totalBytes: BigInt.from(500)),
        );
        await settle();
        task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.stage, 'downloading');
        expect(task.downloadedBytes, 0);

        controller.add(const RepairGameProgress.finished());
        await controller.close();
        await settle();

        task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.completed);
        expect(games().getGameStatus(1), GameStatus.downloaded);
        expect(games().getInstallPath(1), '/games/foo');
      },
    );

    test(
      'allocation errors are kept separate from damaged files and fail the task',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startRepairForInstalled(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.repairController(1);

        controller.add(
          RepairGameProgress.fileNotFound('missing.dat', BigInt.zero),
        );
        controller.add(const RepairGameProgress.allocationError('alloc.dat'));
        controller.add(const RepairGameProgress.finished());
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.errorFiles, ['alloc.dat']);
        expect(task.verifyFailures.keys, ['missing.dat']);
        expect(task.status, TaskStatus.failed);
      },
    );

    test(
      'startRepair after a failed verification reuses its path/build/products',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1, 2],
        );
        final verifyController = backend.verifyController(1);
        verifyController.add(
          VerifyDownloadProgress.fileNotFound('missing.dat', BigInt.zero),
        );
        verifyController.add(VerifyDownloadProgress.finished(BigInt.from(1)));
        await verifyController.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[1]!.status,
          TaskStatus.failed,
        );

        await notifier.startRepair(1);

        expect(backend.callsTo('repairDownload'), hasLength(1));
        final call = backend.callsTo('repairDownload').single;
        expect(call.args['path'], '/games/foo');
        expect(call.args['buildName'], 'build-1');
        expect(call.args['selectedProducts'], [1, 2]);

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.kind, TaskKind.repair);
      },
    );
  });

  group('DownloadsNotifier — late stream error', () {
    test('download: an error with no finished fails the task and the game', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      GamesState games() => container.read(gamesStateProvider);
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.downloadController(1);
      controller.add(
        DownloadGameProgress.downloadProgress(downloadedBytes: BigInt.from(10)),
      );
      controller.addError(Exception('late error'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(games().getGameStatus(1), GameStatus.notInstalled);
    });

    test('verification: an error with no finished fails the task', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.verifyController(1);
      controller.add(VerifyDownloadProgress.progress(BigInt.from(10)));
      controller.addError(Exception('late error'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
    });

    test('repair: an error with no finished fails the task', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);

      await notifier.startRepairForInstalled(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.repairController(1);
      controller.add(
        RepairGameProgress.verification(checkedBytes: BigInt.from(10)),
      );
      controller.addError(Exception('late error'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
    });

    test(
      'known gap: an error arriving after finished still completes the task, '
      'because onDone runs after onError and re-derives status from stage/'
      'errorFiles (see ROADMAP v1.1.2)',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.downloadController(1);
        controller.add(const DownloadGameProgress.finished());
        controller.addError(Exception('late error, after finished'));
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.completed);
        expect(games().getGameStatus(1), GameStatus.downloaded);
      },
    );
  });

  group('DownloadsNotifier — immutability (Phase 5)', () {
    test('an event produces a new task; the old snapshot keeps its old values', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.verifyController(1);

      controller.add(VerifyDownloadProgress.started(BigInt.from(1000)));
      await settle();
      final before = container.read(downloadsStateProvider).tasks[1]!;

      controller.add(VerifyDownloadProgress.progress(BigInt.from(400)));
      await settle();
      final after = container.read(downloadsStateProvider).tasks[1]!;

      expect(identical(before, after), isFalse);
      expect(before.downloadedBytes, 0);
      expect(after.downloadedBytes, 400);
    });

    test('errorFiles and verifyFailures are unmodifiable', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      final controller = backend.verifyController(1);
      controller.add(
        VerifyDownloadProgress.fileNotFound('missing.dat', BigInt.zero),
      );
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(() => task.errorFiles.add('x'), throwsUnsupportedError);
      expect(
        () => task.verifyFailures['x'] = VerifyFailure.missing,
        throwsUnsupportedError,
      );
    });

    test(
      'rapid progress events collapse under the throttle, but the final '
      'terminal event always lands',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'build-1');

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.downloadController(1);

        // No settle() between these -- all but the last should be coalesced
        // by the throttle, and the terminal finished+close must still flush.
        controller.add(
          DownloadGameProgress.started(
            totalFiles: BigInt.from(1),
            totalBytes: BigInt.from(1000),
          ),
        );
        for (var i = 1; i <= 5; i++) {
          controller.add(
            DownloadGameProgress.downloadProgress(
              downloadedBytes: BigInt.from(i * 100),
            ),
          );
        }
        controller.add(const DownloadGameProgress.finished());
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.completed);
        expect(task.downloadedBytes, 500);
      },
    );

    test(
      'a stale stream cannot clobber the task that replaced it',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final staleController = backend.verifyController(1);

        // Dequeues the still-running task above and starts a fresh one on a
        // new controller, without waiting for the old stream to close.
        await notifier.startVerificationForInstalled(
          1,
          path: '/games/foo',
          buildName: 'build-2',
          productIds: [1],
        );
        final freshController = backend.verifyController(1);
        expect(identical(staleController, freshController), isFalse);

        freshController.add(VerifyDownloadProgress.started(BigInt.from(500)));
        await settle();
        final beforeStaleEvent = container.read(downloadsStateProvider).tasks[1]!;

        // An event on the orphaned stream must not overwrite the fresh task.
        staleController.add(VerifyDownloadProgress.started(BigInt.from(999999)));
        await settle();
        final afterStaleEvent = container.read(downloadsStateProvider).tasks[1]!;

        expect(afterStaleEvent.totalBytes, beforeStaleEvent.totalBytes);
        expect(afterStaleEvent.buildName, 'build-2');
        expect(identical(afterStaleEvent, beforeStaleEvent), isTrue);
      },
    );
  });
}
