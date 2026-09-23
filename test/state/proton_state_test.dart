import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease;
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/state/downloads_state.dart' show TaskStatus;
import 'package:lumen/state/games_state.dart';
import 'package:lumen/state/proton_state.dart';
import 'package:lumen/state/shared_preferences_provider.dart';

import '../helpers/container.dart';
import '../helpers/fake_gog_backend.dart';
import '../helpers/fake_proton.dart';
import '../helpers/temp_data_home.dart';

// The notifier throttles progress emits to ~10Hz with a trailing flush (see
// lib/state/emit_throttle.dart's ThrottledTaskBuffer, used by
// ProtonNotifier). Tests wait past that window before asserting on a value
// that arrived via a throttled emit — same as downloads_state_test.dart's
// settle().
Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

const _release = ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000);

void main() {
  late Directory dataHome;

  setUp(() {
    dataHome = useTempDataHome();
  });

  group('ProtonNotifier — downloadRelease', () {
    test(
      'Finished marks the task completed, installed at the reported path, persisted',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(protonStateProvider.notifier);
        final targetDir = '${dataHome.path}/target';

        await notifier.downloadRelease(_release, targetDir);
        final controller = backend.protonDownloadController(_release.tagName);

        controller.add(ProtonDownloadProgress.started(BigInt.from(1000)));
        await settle();
        var task = container
            .read(protonStateProvider)
            .taskFor(_release.tagName)!;
        expect(task.stage, 'downloading');

        controller.add(ProtonDownloadProgress.progress(BigInt.from(1000)));
        await settle();
        task = container.read(protonStateProvider).taskFor(_release.tagName)!;
        expect(task.stage, 'extracting');

        // Deliberately different from '$targetDir/$tag', since the bridge
        // sanitizes the tag for the filesystem.
        final reportedPath = '$targetDir/GE-Proton9_1';
        controller.add(ProtonDownloadProgress.finished(reportedPath));
        await controller.close();
        await settle();

        final state = container.read(protonStateProvider);
        expect(state.taskFor(_release.tagName)!.status, TaskStatus.completed);
        expect(state.isInstalled(_release.tagName), true);
        expect(state.pathFor(_release.tagName), reportedPath);
        // First install with no prior default becomes the default.
        expect(state.defaultVersion, _release.tagName);

        final prefs = container.read(sharedPreferencesProvider);
        final installedJson =
            jsonDecode(prefs.getString('protonInstalled')!)
                as Map<String, dynamic>;
        expect(installedJson[_release.tagName], reportedPath);
        expect(prefs.getString('protonDefault'), _release.tagName);
      },
    );

    test(
      'v1.0.13: a stream closed without Finished is failed, not installed',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(protonStateProvider.notifier);
        final targetDir = '${dataHome.path}/target';

        await notifier.downloadRelease(_release, targetDir);
        final controller = backend.protonDownloadController(_release.tagName);

        controller.add(ProtonDownloadProgress.started(BigInt.from(1000)));
        controller.add(ProtonDownloadProgress.progress(BigInt.from(500)));
        await controller.close();
        await settle();

        final state = container.read(protonStateProvider);
        expect(state.taskFor(_release.tagName)!.status, TaskStatus.failed);
        expect(state.isInstalled(_release.tagName), false);
        expect(state.defaultVersion, null);

        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getString('protonInstalled'), null);
      },
    );

    test('an error sets the task failed', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(protonStateProvider.notifier);
      final targetDir = '${dataHome.path}/target';

      await notifier.downloadRelease(_release, targetDir);
      final controller = backend.protonDownloadController(_release.tagName);
      controller.addError(Exception('boom'));
      await settle();

      expect(
        container.read(protonStateProvider).taskFor(_release.tagName)!.status,
        TaskStatus.failed,
      );
    });

    test(
      'retry after a failure starts a fresh stream and can succeed',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(protonStateProvider.notifier);
        final targetDir = '${dataHome.path}/target';

        await notifier.downloadRelease(_release, targetDir);
        final first = backend.protonDownloadController(_release.tagName);
        first.addError(Exception('boom'));
        await settle();
        expect(
          container.read(protonStateProvider).taskFor(_release.tagName)!.status,
          TaskStatus.failed,
        );

        await notifier.downloadRelease(_release, targetDir);
        expect(backend.callsTo('downloadProtonRelease'), hasLength(2));
        final second = backend.protonDownloadController(_release.tagName);
        expect(identical(first, second), false);

        final reportedPath = '$targetDir/GE-Proton9_1';
        second.add(ProtonDownloadProgress.finished(reportedPath));
        await second.close();
        await settle();

        final state = container.read(protonStateProvider);
        expect(state.taskFor(_release.tagName)!.status, TaskStatus.completed);
        expect(state.isInstalled(_release.tagName), true);
      },
    );

    test(
      'v1.0.12: removeVersion clears per-game overrides pointing at it',
      () async {
        final backend = FakeGogBackend();
        final pathA = fakeProtonInstall('${dataHome.path}/A');
        final pathB = fakeProtonInstall('${dataHome.path}/B');
        final container = await createContainer(
          backend: backend,
          prefs: {
            'protonInstalled': jsonEncode({'A': pathA, 'B': pathB}),
            'protonDefault': 'A',
          },
        );
        addTearDown(backend.closeAll);

        final games = container.read(gamesStateProvider.notifier);
        games.setSelectedBuild(1, 'build-1');
        games.setSelectedBuild(2, 'build-1');
        games.setSelectedBuild(3, 'build-1');
        games.setProtonVersion(1, 'A');
        games.setProtonVersion(2, 'A');
        games.setProtonVersion(3, 'B');

        final protonNotifier = container.read(protonStateProvider.notifier);
        protonNotifier.removeVersion('A');

        final gamesState = container.read(gamesStateProvider);
        expect(gamesState.getProtonVersion(1), null);
        expect(gamesState.getProtonVersion(2), null);
        expect(gamesState.getProtonVersion(3), 'B');

        final protonState = container.read(protonStateProvider);
        expect(protonState.isInstalled('A'), false);
        expect(protonState.isInstalled('B'), true);
        expect(protonState.defaultVersion, null);

        final prefs = container.read(sharedPreferencesProvider);
        final installedJson =
            jsonDecode(prefs.getString('protonInstalled')!)
                as Map<String, dynamic>;
        expect(installedJson.containsKey('A'), false);
        expect(installedJson.containsKey('B'), true);
        expect(prefs.getString('protonDefault'), null);
      },
    );
  });

  group('ProtonNotifier — validate on load (v1.2.5)', () {
    test(
      'a tag whose directory is gone is not installed; prefs are unchanged',
      () async {
        final present = fakeProtonInstall('${dataHome.path}/present');
        final container = await createContainer(
          prefs: {
            'protonInstalled': jsonEncode({
              'present': present,
              'missing': '${dataHome.path}/missing',
            }),
            'protonDefault': 'present',
          },
        );

        final state = container.read(protonStateProvider);
        expect(state.isInstalled('present'), true);
        expect(state.isInstalled('missing'), false);
        expect(state.defaultVersion, 'present');

        final prefs = container.read(sharedPreferencesProvider);
        final installedJson =
            jsonDecode(prefs.getString('protonInstalled')!)
                as Map<String, dynamic>;
        expect(installedJson.containsKey('missing'), true);
        expect(prefs.getString('protonDefault'), 'present');
      },
    );

    test(
      'a directory that exists but has no executable proton is not installed',
      () async {
        Directory(
          '${dataHome.path}/empty',
        ).createSync(recursive: true);
        final container = await createContainer(
          prefs: {
            'protonInstalled': jsonEncode({'empty': '${dataHome.path}/empty'}),
            'protonDefault': 'empty',
          },
        );

        final state = container.read(protonStateProvider);
        expect(state.isInstalled('empty'), false);
        expect(state.defaultVersion, null);
      },
    );

    test(
      'a missing default falls back to null in-memory without touching prefs',
      () async {
        final present = fakeProtonInstall('${dataHome.path}/present');
        final container = await createContainer(
          prefs: {
            'protonInstalled': jsonEncode({'present': present}),
            'protonDefault': 'missing',
          },
        );

        final state = container.read(protonStateProvider);
        expect(state.defaultVersion, null);

        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getString('protonDefault'), 'missing');
      },
    );

    test(
      'a later persist keeps the hidden entry and hidden default in prefs',
      () async {
        final backend = FakeGogBackend();
        final present = fakeProtonInstall('${dataHome.path}/present');
        final container = await createContainer(
          backend: backend,
          prefs: {
            'protonInstalled': jsonEncode({
              'present': present,
              'missing': '${dataHome.path}/missing',
            }),
            'protonDefault': 'missing',
          },
        );
        addTearDown(backend.closeAll);

        final notifier = container.read(protonStateProvider.notifier);
        notifier.setDefault('present');

        final prefs = container.read(sharedPreferencesProvider);
        final installedJson =
            jsonDecode(prefs.getString('protonInstalled')!)
                as Map<String, dynamic>;
        // The hidden 'missing' entry survives the persist triggered by
        // setDefault, instead of being dropped just because it was hidden
        // from ProtonState.installed at load.
        expect(installedJson.containsKey('missing'), true);
        expect(prefs.getString('protonDefault'), 'present');
      },
    );

    test(
      'installing a previously-hidden tag drops it from the unavailable set',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(
          backend: backend,
          prefs: {
            'protonInstalled': jsonEncode({
              _release.tagName: '${dataHome.path}/missing',
            }),
            'protonDefault': _release.tagName,
          },
        );
        addTearDown(backend.closeAll);
        final notifier = container.read(protonStateProvider.notifier);
        final targetDir = '${dataHome.path}/target';

        expect(
          container.read(protonStateProvider).isInstalled(_release.tagName),
          false,
        );

        await notifier.downloadRelease(_release, targetDir);
        final controller = backend.protonDownloadController(_release.tagName);
        final reportedPath = '$targetDir/GE-Proton9_1';
        controller.add(ProtonDownloadProgress.finished(reportedPath));
        await controller.close();
        await settle();

        final state = container.read(protonStateProvider);
        expect(state.isInstalled(_release.tagName), true);
        expect(state.pathFor(_release.tagName), reportedPath);

        final prefs = container.read(sharedPreferencesProvider);
        final installedJson =
            jsonDecode(prefs.getString('protonInstalled')!)
                as Map<String, dynamic>;
        expect(installedJson[_release.tagName], reportedPath);
      },
    );
  });

  group('ProtonNotifier — immutability (Phase 6)', () {
    test(
      'a Progress event produces a new task; the old snapshot keeps its old values',
      () async {
        final backend = FakeGogBackend();
        final container = await createContainer(backend: backend);
        addTearDown(backend.closeAll);
        final notifier = container.read(protonStateProvider.notifier);
        final targetDir = '${dataHome.path}/target';

        await notifier.downloadRelease(_release, targetDir);
        final controller = backend.protonDownloadController(_release.tagName);

        controller.add(ProtonDownloadProgress.started(BigInt.from(1000)));
        await settle();
        final before = container
            .read(protonStateProvider)
            .taskFor(_release.tagName)!;

        controller.add(ProtonDownloadProgress.progress(BigInt.from(200)));
        await settle();
        final after = container
            .read(protonStateProvider)
            .taskFor(_release.tagName)!;

        expect(identical(before, after), isFalse);
        expect(before.transferred, 0);
        expect(after.transferred, 200);
        expect(after.stage, 'downloading');
      },
    );

    test('rapid progress events collapse under the throttle, but the final '
        'terminal event always lands', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(protonStateProvider.notifier);
      final targetDir = '${dataHome.path}/target';

      await notifier.downloadRelease(_release, targetDir);
      final controller = backend.protonDownloadController(_release.tagName);

      // No settle() between these -- all but the last should be coalesced
      // by the throttle, and the terminal finished+close must still flush.
      controller.add(ProtonDownloadProgress.started(BigInt.from(1000)));
      for (var i = 1; i <= 5; i++) {
        controller.add(ProtonDownloadProgress.progress(BigInt.from(i * 100)));
      }
      final reportedPath = '$targetDir/GE-Proton9_1';
      controller.add(ProtonDownloadProgress.finished(reportedPath));
      await controller.close();
      await settle();

      final state = container.read(protonStateProvider);
      final task = state.taskFor(_release.tagName)!;
      expect(task.status, TaskStatus.completed);
      expect(task.transferred, 500);
      expect(state.isInstalled(_release.tagName), true);
    });

    test('a stale stream cannot clobber the task that replaced it', () async {
      final backend = FakeGogBackend();
      final container = await createContainer(backend: backend);
      addTearDown(backend.closeAll);
      final notifier = container.read(protonStateProvider.notifier);
      final targetDir = '${dataHome.path}/target';

      await notifier.downloadRelease(_release, targetDir);
      final staleController = backend.protonDownloadController(
        _release.tagName,
      );
      staleController.addError(Exception('boom'));
      await settle();

      // Retrying a failed download starts a fresh stream, without the old
      // (errored) stream's controller ever being closed.
      await notifier.downloadRelease(_release, targetDir);
      final freshController = backend.protonDownloadController(
        _release.tagName,
      );
      expect(identical(staleController, freshController), isFalse);

      freshController.add(ProtonDownloadProgress.started(BigInt.from(500)));
      await settle();
      final beforeStaleEvent = container
          .read(protonStateProvider)
          .taskFor(_release.tagName)!;

      // An event on the orphaned stream must not overwrite the fresh task.
      staleController.add(ProtonDownloadProgress.progress(BigInt.from(999)));
      await settle();
      final afterStaleEvent = container
          .read(protonStateProvider)
          .taskFor(_release.tagName)!;

      expect(identical(afterStaleEvent, beforeStaleEvent), isTrue);
      expect(afterStaleEvent.total, 500);
    });
  });
}
