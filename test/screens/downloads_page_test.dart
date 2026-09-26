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
}
