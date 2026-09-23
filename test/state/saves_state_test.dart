import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/common/app_paths.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/saves_state.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/temp_data_home.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    useTempDataHome();
  });

  /// Seeds game [gameId] as installed at [installPath] with [buildName], and
  /// (unless [withPfx] is false) creates the Wine prefix dir Proton would
  /// have created on first launch, so a sync can actually start.
  void seedInstalledGame(
    dynamic container,
    int gameId, {
    String buildName = 'build-1',
    String installPath = '/games/foo',
    bool withPfx = true,
  }) {
    final notifier = container.read(gamesStateProvider.notifier);
    notifier.setSelectedBuild(gameId, buildName);
    notifier.markInstalled(gameId, installPath);
    if (withPfx) {
      Directory(
        '${protonPrefixDir(gameId)}/pfx',
      ).createSync(recursive: true);
    }
  }

  group('SavesNotifier — download', () {
    test('progress is byte-counted, and prefix/installPath are passed through', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);
      final controller = backend.saveDownloadController(1);

      final call = backend.callsTo('downloadSaves').single;
      expect(call.args['prefix'], '${protonPrefixDir(1)}/pfx');
      expect(call.args['installPath'], '/games/foo');
      expect(call.args['buildName'], 'build-1');

      controller.add(
        DownloadSavesProgress.started(
          totalFiles: BigInt.from(2),
          totalBytes: BigInt.from(100),
        ),
      );
      await settle();
      var task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.filesTotal, 2);
      expect(task.total, 100);
      expect(task.progress, 0.0);

      controller.add(
        DownloadSavesProgress.fileStarted(
          name: 'save1.dat',
          destination: '/whatever',
          totalBytes: BigInt.from(50),
        ),
      );
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.currentFile, 'save1.dat');
      expect(task.fileTotal, 50);

      controller.add(
        DownloadSavesProgress.progress(
          downloadedBytes: BigInt.from(50),
          fileDownloadedBytes: BigInt.from(50),
        ),
      );
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.transferred, 50);
      expect(task.progress, 0.5);

      controller.add(const DownloadSavesProgress.fileFinished(name: 'save1.dat'));
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.filesProcessed, 1);
      expect(task.currentFile, null);

      controller.add(const DownloadSavesProgress.finished());
      await controller.close();
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.completed);
    });

    test('isEmpty: zero-file finish', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);
      final controller = backend.saveDownloadController(1);

      controller.add(
        DownloadSavesProgress.started(
          totalFiles: BigInt.from(0),
          totalBytes: BigInt.from(0),
        ),
      );
      controller.add(const DownloadSavesProgress.finished());
      await controller.close();
      await settle();

      final task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.completed);
      expect(task.isEmpty, true);
    });

    test('a stream error sets failed/error', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);
      final controller = backend.saveDownloadController(1);

      controller.addError(Exception('boom'));
      await settle();

      final task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, contains('boom'));
    });

    test('not installed: fails without a backend call', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      // No seedInstalledGame call — game 1 has no GameConfig at all.

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);

      final task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.failed);
      expect(task.error, 'game is not installed');
      expect(backend.callsTo('downloadSaves'), isEmpty);
    });

    test(
      'v1.0.14: no pfx fails early with a clear message and creates no directory',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        seedInstalledGame(container, 1, withPfx: false);

        final notifier = container.read(savesStateProvider.notifier);
        await notifier.downloadSaves(1);

        final task = container.read(savesStateProvider).taskFor(1)!;
        expect(task.status, TaskStatus.failed);
        expect(task.error, 'launch the game once to set up its Wine prefix');
        expect(Directory(protonPrefixDir(1)).existsSync(), false);
        expect(
          container.read(gamesStateProvider).getProtonPrefixPath(1),
          null,
        );
        expect(backend.callsTo('downloadSaves'), isEmpty);
        expect(backend.callsTo('uploadSaves'), isEmpty);
      },
    );

    test('a finished stream is cleared before a re-run', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);
      final first = backend.saveDownloadController(1);
      first.add(const DownloadSavesProgress.finished());
      await first.close();
      await settle();
      expect(
        container.read(savesStateProvider).taskFor(1)!.status,
        TaskStatus.completed,
      );

      await notifier.downloadSaves(1);
      expect(backend.callsTo('downloadSaves'), hasLength(2));
      final second = backend.saveDownloadController(1);
      expect(identical(first, second), false);

      second.add(
        DownloadSavesProgress.started(
          totalFiles: BigInt.from(1),
          totalBytes: BigInt.from(10),
        ),
      );
      second.add(const DownloadSavesProgress.finished());
      await second.close();
      await settle();

      final task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.completed);
      expect(task.filesTotal, 1);
    });

    test('a second sync while one is running is a no-op', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.downloadSaves(1);
      await notifier.downloadSaves(1);

      expect(backend.callsTo('downloadSaves'), hasLength(1));
    });
  });

  group('SavesNotifier — upload', () {
    test('progress is file-counted, not byte-counted', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.uploadSaves(1);
      final controller = backend.saveUploadController(1);

      controller.add(UploadSavesProgress.started(totalFiles: BigInt.from(4)));
      await settle();
      var task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.filesTotal, 4);
      expect(task.total, 0);
      expect(task.progress, 0.0);

      controller.add(
        UploadSavesProgress.progress(
          uploadedBytes: BigInt.from(999),
          fileUploadedBytes: BigInt.from(999),
        ),
      );
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      // Upload's job-level `total` is never set by the bridge, so byte
      // progress never numerically applies to `progress` for uploads.
      expect(task.progress, 0.0);

      controller.add(
        const UploadSavesProgress.fileFinished(name: 'save1.dat'),
      );
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.filesProcessed, 1);
      expect(task.progress, 0.25);

      controller.add(const UploadSavesProgress.finished());
      await controller.close();
      await settle();
      task = container.read(savesStateProvider).taskFor(1)!;
      expect(task.status, TaskStatus.completed);
    });

    test('a finished stream is cleared before a re-run', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      seedInstalledGame(container, 1);

      final notifier = container.read(savesStateProvider.notifier);
      await notifier.uploadSaves(1);
      final first = backend.saveUploadController(1);
      first.add(const UploadSavesProgress.finished());
      await first.close();
      await settle();

      await notifier.uploadSaves(1);
      expect(backend.callsTo('uploadSaves'), hasLength(2));
      final second = backend.saveUploadController(1);
      expect(identical(first, second), false);

      second.add(const UploadSavesProgress.finished());
      await second.close();
      await settle();
      expect(
        container.read(savesStateProvider).taskFor(1)!.status,
        TaskStatus.completed,
      );
    });
  });
}
