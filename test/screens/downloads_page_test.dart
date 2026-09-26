import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/screens/home/pages/downloads_page.dart';
import 'package:lumen/state/downloads_state.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart'
    hide GameBuild, DownloadableProduct, ProtonRelease, InstallSize;

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('a running repair can be cancelled from its card', (
    tester,
  ) async {
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
    );

    await container
        .read(downloadsStateProvider.notifier)
        .startRepairForInstalled(
          1,
          path: '/games/foo',
          buildName: 'build-1',
          productIds: [1],
        );
    backend
        .repairController(1)
        .add(RepairGameProgress.verification(checkedBytes: BigInt.from(10)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('1 active · 0 completed'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Repair cancelled — some files may still be damaged'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('0 active · 0 completed'), findsOneWidget);
  });

  testWidgets('a running download offers Pause and Cancel; paused, Resume', (
    tester,
  ) async {
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
    );
    final notifier = container.read(downloadsStateProvider.notifier);

    // startDownload inspects the install folder with real I/O, which never
    // completes inside the widget test's fake-async zone.
    await tester.runAsync(
      () => notifier.startDownload(
        1,
        path: '/games/foo',
        buildName: 'build-1',
        productIds: [1],
      ),
    );
    backend
        .downloadController(1)
        .add(
          DownloadGameProgress.started(
            totalFiles: BigInt.from(2),
            totalBytes: BigInt.from(1000),
          ),
        );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);

    await tester.tap(find.text('Pause'));
    // The job's stream was subscribed inside runAsync, so its Cancelled
    // event is delivered in the real zone.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.textContaining('Paused'), findsOneWidget);
    expect(find.text('0 active · 0 completed'), findsOneWidget);
  });

  testWidgets('a paused game with no task is listed as interrupted and can '
      'be resumed', (tester) async {
    final dir = Directory.systemTemp.createTempSync('lumen_test_install');
    addTearDown(() => dir.deleteSync(recursive: true));
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
      prefs: {
        'games':
            '{"version": 2, "games": {"1": {"status": "downloading", '
            '"selectedBuild": "build-1", "productIds": [7], '
            '"pendingInstallPath": "${dir.path}"}}}',
      },
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Paused — interrupted'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('0 active · 0 completed'), findsOneWidget);

    await tester.runAsync(
      () => container.read(downloadsStateProvider.notifier).resumeDownload(1),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(backend.callsTo('repairDownload'), hasLength(1));
    expect(find.text('Paused — interrupted'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('a failed repair can be retried or dismissed, and a cancelled '
      'one retried', (tester) async {
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
    );
    final notifier = container.read(downloadsStateProvider.notifier);

    await notifier.startRepairForInstalled(
      1,
      path: '/games/foo',
      buildName: 'build-1',
      productIds: [1],
    );
    backend.repairController(1).addError(Exception('disk on fire'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('disk on fire'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(backend.callsTo('repairDownload'), hasLength(2));
    expect(find.text('Retry'), findsNothing);
    expect(find.byTooltip('Dismiss'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Retry'), findsNothing);
    expect(find.text('No active downloads'), findsOneWidget);
  });

  testWidgets('a failed download shows its error with Retry and dismiss', (
    tester,
  ) async {
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
    );
    final notifier = container.read(downloadsStateProvider.notifier);

    await tester.runAsync(
      () => notifier.startDownload(
        1,
        path: '/games/missing',
        buildName: 'build-1',
        productIds: [1],
      ),
    );
    backend.downloadController(1).addError(Exception('network down'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.runAsync(() => notifier.retryDownload(1));
    await tester.pump(const Duration(milliseconds: 200));

    expect(backend.callsTo('downloadGame'), hasLength(2));
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Clear finished removes finished cards and keeps running ones', (
    tester,
  ) async {
    final backend = FakeGogBackend();
    final container = await pumpApp(
      tester,
      const DownloadsPage(),
      backend: backend,
    );
    final notifier = container.read(downloadsStateProvider.notifier);
    expect(find.text('Clear finished'), findsNothing);

    await notifier.startRepairForInstalled(
      1,
      path: '/games/a',
      buildName: 'build-1',
      productIds: [1],
    );
    backend.repairController(1).addError(Exception('boom'));
    await notifier.startRepairForInstalled(
      2,
      path: '/games/b',
      buildName: 'build-1',
      productIds: [2],
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Clear finished'), findsOneWidget);

    await tester.tap(find.text('Clear finished'));
    await tester.pump(const Duration(milliseconds: 200));

    final tasks = container.read(downloadsStateProvider).tasks;
    expect(tasks.keys, [2]);
    expect(find.text('Clear finished'), findsNothing);
    expect(find.text('1 active · 0 completed'), findsOneWidget);
  });
}
