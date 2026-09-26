import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/state/downloads_state.dart';
import 'package:lumen/state/games_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/temp_data_home.dart';

/// The notifier throttles progress emits to ~10Hz with a trailing flush (see
/// `DownloadsNotifier._emitThrottle`). Tests wait past that window before
/// asserting on a value that arrived via a throttled emit, so they keep
/// passing unchanged once Phase 5 makes tasks immutable (the throttle then
/// gates a state *replacement* instead of a mutation, but the timing is the
/// same).
Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

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
      container
          .read(gamesStateProvider.notifier)
          .setSelectedBuild(1, 'build-1');

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
        DownloadGameProgress.downloadProgress(
          downloadedBytes: BigInt.from(400),
        ),
      );
      await settle();
      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.stage, 'downloading');
      expect(task.downloadedBytes, 400);
      expect(task.progress, 400 / 1000);
    });

    test(
      'finished + close marks the task completed and the game installed',
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
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.completed);
        expect(games().getGameStatus(1), GameStatus.downloaded);
        expect(games().getInstallPath(1), '/games/foo');
      },
    );

    test(
      'v1.0.5: a download that finishes with allocation errorFiles is not marked installed',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);
        container
            .read(gamesStateProvider.notifier)
            .setSelectedBuild(1, 'build-1');

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
      container
          .read(gamesStateProvider.notifier)
          .setSelectedBuild(1, 'build-1');

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

    test(
      'a thrown error starting the stream fails the task immediately',
      () async {
        final backend = FakeGogBackend()
          ..throwOn['downloadGame'] = Exception('boom');
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);
        container
            .read(gamesStateProvider.notifier)
            .setSelectedBuild(1, 'build-1');

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.failed);
        expect(games().getGameStatus(1), GameStatus.notInstalled);
      },
    );

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
          VerifyDownloadProgress.couldNotResolvePath(
            'bad-path.dat',
            BigInt.zero,
          ),
        );
        controller.add(VerifyDownloadProgress.finished(BigInt.from(3)));
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.verifyFailures['missing.dat'], VerifyFailure.missing);
        expect(task.verifyFailures['corrupt.dat'], VerifyFailure.corrupt);
        expect(task.verifyFailures['bad-path.dat'], VerifyFailure.unreadable);
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
        expect(
          task.verifyFailures.keys,
          unorderedEquals(['missing.dat', 'corrupt.dat']),
        );
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
    test(
      'download: an error with no finished fails the task and the game',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);
        GamesState games() => container.read(gamesStateProvider);
        container
            .read(gamesStateProvider.notifier)
            .setSelectedBuild(1, 'build-1');

        await notifier.startDownload(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        final controller = backend.downloadController(1);
        controller.add(
          DownloadGameProgress.downloadProgress(
            downloadedBytes: BigInt.from(10),
          ),
        );
        controller.addError(Exception('late error'));
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.failed);
        expect(games().getGameStatus(1), GameStatus.notInstalled);
      },
    );

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

    test('download: an error arriving after finished still fails the task, not '
        'completes it (v1.1.2 — onDone no longer re-derives status once onError '
        'has already failed the task)', () async {
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
      expect(task.status, TaskStatus.failed);
      expect(games().getGameStatus(1), GameStatus.notInstalled);
    });

    test('verification: an error arriving after finished still fails the task '
        '(v1.1.2)', () async {
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
      controller.add(VerifyDownloadProgress.finished(BigInt.from(0)));
      controller.addError(Exception('late error, after finished'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
    });

    test('repair: an error arriving after finished still fails the task '
        '(v1.1.2)', () async {
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
      controller.add(const RepairGameProgress.finished());
      controller.addError(Exception('late error, after finished'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
    });
  });

  group('DownloadsNotifier — error text', () {
    test(
      'verification: a stream error records the bridge error text',
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
        final controller = backend.verifyController(1);
        controller.addError(Exception('gog says no'));
        await controller.close();
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.failed);
        expect(task.error, contains('gog says no'));
      },
    );

    test('download: a stream error records the bridge error text', () async {
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
      final controller = backend.downloadController(1);
      controller.addError(Exception('gog says no'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, contains('gog says no'));
    });

    test('repair: a stream error records the bridge error text', () async {
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
      controller.addError(Exception('gog says no'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, contains('gog says no'));
    });

    test(
      'a build lookup that fails to even start the stream records "could not start"',
      () async {
        final backend = FakeGogBackend()
          ..throwOn['verifyDownload'] = Exception('boom');
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startVerification(
          1,
          path: '/games/foo',
          buildName: 'unknown-build',
          productIds: [1],
        );

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.failed);
        expect(task.error, contains("couldn't start"));
      },
    );
  });

  group('DownloadsNotifier — immutability (Phase 5)', () {
    test(
      'an event produces a new task; the old snapshot keeps its old values',
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
      },
    );

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

    test('rapid progress events collapse under the throttle, but the final '
        'terminal event always lands', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(downloadsStateProvider.notifier);
      container
          .read(gamesStateProvider.notifier)
          .setSelectedBuild(1, 'build-1');

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
    });

    test('a stale stream cannot clobber the task that replaced it', () async {
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
    });
  });

  group('DownloadsNotifier — cancel (Phase 4)', () {
    test(
      'cancelling a verification ends cancelled and installs nothing',
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
        backend
            .verifyController(1)
            .add(VerifyDownloadProgress.started(BigInt.from(500)));
        await settle();

        notifier.cancel(1);
        expect(backend.jobCancel('verifyDownload').isCancelled, isTrue);
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.cancelled);
        expect(task.error, isNull);
        final games = container.read(gamesStateProvider);
        expect(games.getGameStatus(1), GameStatus.notInstalled);
        expect(games.getInstallPath(1), isNull);
      },
    );

    test(
      'cancelling a repair ends cancelled and the game stays downloaded',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        container
            .read(gamesStateProvider.notifier)
            .markInstalled(1, '/games/foo');
        final notifier = container.read(downloadsStateProvider.notifier);

        await notifier.startRepairForInstalled(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
        backend
            .repairController(1)
            .add(
              RepairGameProgress.verification(checkedBytes: BigInt.from(10)),
            );
        await settle();

        notifier.cancel(1);
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.cancelled);
        expect(task.error, isNull);
        expect(
          container.read(gamesStateProvider).getGameStatus(1),
          GameStatus.downloaded,
        );
      },
    );

    test('a cancelled task can be restarted', () async {
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
      notifier.cancel(1);
      await settle();
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.cancelled,
      );

      await notifier.startVerification(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      );
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.running,
      );
    });

    test("a replaced job's late Cancelled can't clobber the new task, and "
        'cancel reaches the new job', () async {
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
      final staleCancel = backend.jobCancel('verifyDownload');

      await notifier.startVerificationForInstalled(
        1,
        path: '/games/foo',
        buildName: 'build-2',
        productIds: [1],
      );
      final freshCancel = backend.jobCancel('verifyDownload');
      expect(identical(staleCancel, freshCancel), isFalse);

      // The orphaned stream ends with Cancelled and closes.
      staleController.add(const VerifyDownloadProgress.cancelled());
      await staleController.close();
      await settle();
      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.running);
      expect(task.buildName, 'build-2');

      // The stale stream's terminal events didn't unregister the new handle.
      notifier.cancel(1);
      expect(freshCancel.isCancelled, isTrue);
      expect(staleCancel.isCancelled, isFalse);
      await settle();
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.cancelled,
      );
    });

    test(
      'cancel is a no-op without a running verification or repair',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(downloadsStateProvider.notifier);

        // No task at all.
        notifier.cancel(1);

        // A running download (cancel for downloads is Phase 5).
        await notifier.startDownload(
          2,
          path: '/games/bar',
          buildName: 'build-1',
          productIds: [2],
        );
        notifier.cancel(2);
        expect(backend.jobCancel('downloadGame').isCancelled, isFalse);
        expect(
          container.read(downloadsStateProvider).tasks[2]!.status,
          TaskStatus.running,
        );

        // A finished verification.
        await notifier.startVerification(
          3,
          path: '/games/baz',
          buildName: 'build-1',
          productIds: [3],
        );
        final controller = backend.verifyController(3);
        controller.add(VerifyDownloadProgress.finished(BigInt.zero));
        await controller.close();
        await settle();
        expect(
          container.read(downloadsStateProvider).tasks[3]!.status,
          TaskStatus.completed,
        );
        notifier.cancel(3);
        expect(backend.jobCancel('verifyDownload').isCancelled, isFalse);
      },
    );
  });

  group('DownloadsNotifier — pause, resume and cancel downloads (Phase 5)', () {
    /// Seeds a config for game 1 (and 2, for the containment test) so
    /// `setGameStatus` has something to update.
    Future<(FakeGogBackend, ProviderContainer, DownloadsNotifier)> setUp(
      Map<String, Object> prefs,
    ) async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend, prefs: prefs);
      final notifier = container.read(downloadsStateProvider.notifier);
      container
          .read(gamesStateProvider.notifier)
          .setSelectedBuild(1, 'build-1');
      container.read(gamesStateProvider.notifier).addProductId(1, 7);
      return (backend, container, notifier);
    }

    Future<Directory> emptyDir() async {
      final dir = Directory.systemTemp.createTempSync('lumen_test_install');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      return dir;
    }

    Future<void> startAndProgress(
      FakeGogBackend backend,
      DownloadsNotifier notifier,
      String path,
    ) async {
      await notifier.startDownload(
        1,
        path: path,
        buildName: 'build-1',
        productIds: [7],
      );
      backend
          .downloadController(1)
          .add(
            DownloadGameProgress.started(
              totalFiles: BigInt.from(2),
              totalBytes: BigInt.from(1000),
            ),
          );
      backend
          .downloadController(1)
          .add(
            DownloadGameProgress.downloadProgress(
              downloadedBytes: BigInt.from(400),
            ),
          );
      await settle();
    }

    test(
      'pause ends paused, the game is paused and its path is persisted',
      () async {
        final (backend, container, notifier) = await setUp({});
        await startAndProgress(backend, notifier, '/games/foo');
        expect(
          container.read(gamesStateProvider).getPendingInstallPath(1),
          '/games/foo',
        );

        notifier.pause(1);
        expect(backend.jobCancel('downloadGame').isCancelled, isTrue);
        await settle();

        final task = container.read(downloadsStateProvider).tasks[1]!;
        expect(task.status, TaskStatus.paused);
        expect(task.error, isNull);
        final games = container.read(gamesStateProvider);
        expect(games.getGameStatus(1), GameStatus.paused);
        expect(games.getPendingInstallPath(1), '/games/foo');
        expect(games.getInstallPath(1), isNull);
      },
    );

    test('pausing while allocating behaves the same', () async {
      final (backend, container, notifier) = await setUp({});
      await notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [7],
      );
      backend
          .downloadController(1)
          .add(
            DownloadGameProgress.fileAllocationStarted(
              totalFiles: BigInt.from(3),
              totalBytes: BigInt.from(1000),
            ),
          );
      await settle();
      expect(
        container.read(downloadsStateProvider).tasks[1]!.stage,
        'allocating',
      );

      notifier.pause(1);
      await settle();

      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.paused,
      );
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.paused,
      );
    });

    test('pause is a no-op for anything but a running download', () async {
      final (backend, container, notifier) = await setUp({});
      await notifier.startRepairForInstalled(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [7],
      );
      notifier.pause(1);
      notifier.pause(99);
      expect(backend.jobCancel('repairDownload').isCancelled, isFalse);
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.running,
      );
    });

    test('resume runs repairDownload (not downloadGame) with the saved params '
        'and installs the game', () async {
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      notifier.pause(1);
      await settle();

      await notifier.resumeDownload(1);

      expect(backend.callsTo('downloadGame'), hasLength(1));
      final repair = backend.callsTo('repairDownload');
      expect(repair, hasLength(1));
      expect(repair.single.args['path'], dir.path);
      expect(repair.single.args['buildName'], 'build-1');
      var task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.kind, TaskKind.download);
      expect(task.resumed, isTrue);
      expect(task.status, TaskStatus.running);
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.downloading,
      );

      final controller = backend.repairController(1);
      controller.add(const RepairGameProgress.finished());
      await controller.close();
      await settle();

      task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.completed);
      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.downloaded);
      expect(games.getInstallPath(1), dir.path);
      expect(games.getPendingInstallPath(1), isNull);
      expect(games.games[1]!.ownsPendingInstallDir, isFalse);
    });

    test(
      'resume with no task takes its params from the persisted config',
      () async {
        final dir = await emptyDir();
        final json =
            '{"version": 2, "games": {"1": {"status": "paused", '
            '"selectedBuild": "b-9", "productIds": [4, 5], '
            '"pendingInstallPath": "${dir.path}"}}}';
        final (backend, container, notifier) = await setUp({'games': json});
        // setUp's seeding must not have clobbered the persisted values.
        container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'b-9');
        container.read(gamesStateProvider.notifier).setProductIds(1, {4, 5});

        await notifier.resumeDownload(1);

        final call = backend.callsTo('repairDownload').single;
        expect(call.args['path'], dir.path);
        expect(call.args['buildName'], 'b-9');
        expect(call.args['selectedProducts'], [4, 5]);
        expect(
          container.read(downloadsStateProvider).tasks[1]!.resumed,
          isTrue,
        );
      },
    );

    test('resume is a no-op unless the game is paused', () async {
      final (backend, _, notifier) = await setUp({});
      await notifier.resumeDownload(1);
      expect(backend.callsTo('repairDownload'), isEmpty);
    });

    test('a failed resume goes back to paused, not notInstalled', () async {
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      notifier.pause(1);
      await settle();
      await notifier.resumeDownload(1);

      final controller = backend.repairController(1);
      controller.addError(Exception('network down'));
      await controller.close();
      await settle();

      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, contains('network down'));
      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.paused);
      expect(games.getPendingInstallPath(1), dir.path);
    });

    test('a persisted "downloading" entry resumes after a restart through '
        'repairDownload with its persisted params', () async {
      final dir = await emptyDir();
      final json =
          '{"version": 2, "games": {"1": {"status": "downloading", '
          '"selectedBuild": "b-9", "productIds": [4], '
          '"pendingInstallPath": "${dir.path}"}}}';
      final (backend, container, notifier) = await setUp({'games': json});
      container.read(gamesStateProvider.notifier).setSelectedBuild(1, 'b-9');
      container.read(gamesStateProvider.notifier).setProductIds(1, {4});
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.paused,
      );

      await notifier.resumeDownload(1);

      expect(backend.callsTo('downloadGame'), isEmpty);
      expect(backend.callsTo('repairDownload').single.args['path'], dir.path);
    });

    test('resume with a missing folder fails with a specific message and '
        'clears nothing', () async {
      final dir = await emptyDir();
      final missing = '${dir.path}/gone';
      final json =
          '{"version": 2, "games": {"1": {"status": "paused", '
          '"selectedBuild": "b-9", "productIds": [4], '
          '"pendingInstallPath": "$missing"}}}';
      final (backend, container, notifier) = await setUp({'games': json});

      await notifier.resumeDownload(1);

      expect(backend.callsTo('repairDownload'), isEmpty);
      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, 'The install folder $missing no longer exists');
      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.paused);
      expect(games.getPendingInstallPath(1), missing);
    });

    test('two quick resumes start only one job', () async {
      final dir = await emptyDir();
      final (backend, _, notifier) = await setUp({});
      await startAndProgress(backend, notifier, dir.path);
      notifier.pause(1);
      await settle();

      await Future.wait([
        notifier.resumeDownload(1),
        notifier.resumeDownload(1),
      ]);

      expect(backend.callsTo('repairDownload'), hasLength(1));
    });

    test('startDownload on a paused game is a no-op', () async {
      final (backend, _, notifier) = await setUp({});
      await startAndProgress(backend, notifier, '/games/foo');
      notifier.pause(1);
      await settle();

      await notifier.startDownload(
        1,
        path: '/games/other',
        buildName: 'build-1',
        productIds: [7],
      );

      expect(backend.callsTo('downloadGame'), hasLength(1));
    });

    test(
      'a failed download clears the pending path and resets the game',
      () async {
        final (backend, container, notifier) = await setUp({});
        await startAndProgress(backend, notifier, '/games/foo');
        final controller = backend.downloadController(1);
        controller.addError(Exception('boom'));
        await controller.close();
        await settle();

        final games = container.read(gamesStateProvider);
        expect(games.getGameStatus(1), GameStatus.notInstalled);
        expect(games.getPendingInstallPath(1), isNull);
      },
    );

    test('cancelling a running download stops the job first, then deletes '
        'the folder it owned and resets the game', () async {
      useTempDataHome();
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      File('${dir.path}/data.bin').writeAsStringSync('partial');
      expect(
        container.read(gamesStateProvider).games[1]!.ownsPendingInstallDir,
        isTrue,
      );

      await notifier.cancelDownload(1, deleteFiles: true);

      expect(backend.jobCancel('downloadGame').isCancelled, isTrue);
      expect(dir.existsSync(), isFalse);
      expect(container.read(downloadsStateProvider).tasks[1], isNull);
      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.notInstalled);
      expect(games.getPendingInstallPath(1), isNull);
      expect(games.games[1]!.ownsPendingInstallDir, isFalse);
    });

    test('cancelling with "keep files" leaves the folder alone', () async {
      useTempDataHome();
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      File('${dir.path}/data.bin').writeAsStringSync('partial');

      await notifier.cancelDownload(1, deleteFiles: false);

      expect(File('${dir.path}/data.bin').existsSync(), isTrue);
      expect(container.read(downloadsStateProvider).tasks[1], isNull);
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.notInstalled,
      );
    });

    test('a paused download can be cancelled too', () async {
      useTempDataHome();
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      notifier.pause(1);
      await settle();

      await notifier.cancelDownload(1, deleteFiles: true);

      expect(dir.existsSync(), isFalse);
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.notInstalled,
      );
    });

    test("deleting is refused for a folder that wasn't empty at the start, "
        'and the game stays paused', () async {
      useTempDataHome();
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      File('${dir.path}/mine.txt').writeAsStringSync('not the download\'s');
      await startAndProgress(backend, notifier, dir.path);
      expect(
        container.read(gamesStateProvider).games[1]!.ownsPendingInstallDir,
        isFalse,
      );

      await expectLater(
        notifier.cancelDownload(1, deleteFiles: true),
        throwsA(isA<Exception>()),
      );

      expect(File('${dir.path}/mine.txt').existsSync(), isTrue);
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.paused,
      );
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.paused,
      );
    });

    test("deleting is refused for a folder that contains another game's "
        'install', () async {
      useTempDataHome();
      final (backend, container, notifier) = await setUp({});
      final dir = await emptyDir();
      await startAndProgress(backend, notifier, dir.path);
      container
          .read(gamesStateProvider.notifier)
          .markInstalled(2, '${dir.path}/other-game');

      await expectLater(
        notifier.cancelDownload(1, deleteFiles: true),
        throwsA(isA<Exception>()),
      );

      expect(dir.existsSync(), isTrue);
      expect(
        container.read(gamesStateProvider).getGameStatus(1),
        GameStatus.paused,
      );
    });
  });

  group('DownloadsNotifier — retry and clear finished (Phase 8)', () {
    Future<(FakeGogBackend, ProviderContainer, DownloadsNotifier)>
    setUp() async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      final notifier = container.read(downloadsStateProvider.notifier);
      container
          .read(gamesStateProvider.notifier)
          .setSelectedBuild(1, 'build-1');
      return (backend, container, notifier);
    }

    Directory tempDir({bool withFile = false}) {
      final dir = Directory.systemTemp.createTempSync('lumen_test_install');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      if (withFile) File('${dir.path}/data.bin').writeAsBytesSync([1, 2, 3]);
      return dir;
    }

    Future<void> failDownload(
      FakeGogBackend backend,
      DownloadsNotifier notifier,
      String path,
    ) async {
      await notifier.startDownload(
        1,
        path: path,
        buildName: 'build-1',
        productIds: [7],
      );
      final controller = backend.downloadController(1);
      controller.addError(Exception('network down'));
      await controller.close();
      await settle();
    }

    test('a failed download with files on disk becomes paused, and retry '
        'resumes it through repairDownload', () async {
      final (backend, container, notifier) = await setUp();
      final dir = tempDir(withFile: true);

      await failDownload(backend, notifier, dir.path);

      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.paused);
      expect(games.getPendingInstallPath(1), dir.path);
      expect(
        container.read(downloadsStateProvider).tasks[1]!.status,
        TaskStatus.failed,
      );

      await notifier.retryDownload(1);

      expect(backend.callsTo('repairDownload'), hasLength(1));
      expect(backend.callsTo('downloadGame'), hasLength(1));
      expect(backend.callsTo('repairDownload').single.args['path'], dir.path);
      final task = container.read(downloadsStateProvider).tasks[1]!;
      expect(task.resumed, isTrue);
      expect(task.status, TaskStatus.running);
    });

    test('a failed download into an empty folder resets the game, and retry '
        'starts a fresh download', () async {
      final (backend, container, notifier) = await setUp();
      final dir = tempDir();

      await failDownload(backend, notifier, dir.path);

      final games = container.read(gamesStateProvider);
      expect(games.getGameStatus(1), GameStatus.notInstalled);
      expect(games.getPendingInstallPath(1), isNull);

      await notifier.retryDownload(1);

      expect(backend.callsTo('downloadGame'), hasLength(2));
      expect(backend.callsTo('repairDownload'), isEmpty);
    });

    test('retryDownload is a no-op without a failed download', () async {
      final (backend, container, notifier) = await setUp();

      await notifier.retryDownload(1);
      await notifier.startRepairForInstalled(
        2,
        path: '/games/bar',
        buildName: 'build-1',
        productIds: [2],
      );
      await notifier.retryDownload(2);

      expect(backend.callsTo('downloadGame'), isEmpty);
      expect(backend.callsTo('repairDownload'), hasLength(1));
      expect(container.read(downloadsStateProvider).tasks, hasLength(1));
    });

    test('clearFinished removes completed, failed and cancelled tasks but '
        'keeps running, paused and resumable ones', () async {
      final (backend, container, notifier) = await setUp();
      addTearDown(backend.closeAll);
      TaskStatus? statusOf(int id) =>
          container.read(downloadsStateProvider).tasks[id]?.status;

      // 2: completed verification. 3: failed repair. 4: cancelled repair.
      await notifier.startVerification(
        2,
        path: '/games/b',
        buildName: 'build-1',
        productIds: [2],
      );
      backend
          .verifyController(2)
          .add(VerifyDownloadProgress.finished(BigInt.zero));
      await backend.verifyController(2).close();
      await notifier.startRepairForInstalled(
        3,
        path: '/games/c',
        buildName: 'build-1',
        productIds: [3],
      );
      backend.repairController(3).addError(Exception('boom'));
      await backend.repairController(3).close();
      await notifier.startRepairForInstalled(
        4,
        path: '/games/d',
        buildName: 'build-1',
        productIds: [4],
      );
      notifier.cancel(4);
      // 5: running repair. 1: failed download of a paused (resumable) game.
      await notifier.startRepairForInstalled(
        5,
        path: '/games/e',
        buildName: 'build-1',
        productIds: [5],
      );
      final dir = tempDir(withFile: true);
      await failDownload(backend, notifier, dir.path);
      await settle();

      expect(statusOf(2), TaskStatus.completed);
      expect(statusOf(3), TaskStatus.failed);
      expect(statusOf(4), TaskStatus.cancelled);
      expect(statusOf(5), TaskStatus.running);
      expect(statusOf(1), TaskStatus.failed);

      notifier.clearFinished();

      expect(statusOf(2), isNull);
      expect(statusOf(3), isNull);
      expect(statusOf(4), isNull);
      expect(statusOf(5), TaskStatus.running);
      expect(statusOf(1), TaskStatus.failed);
    });
  });
}
