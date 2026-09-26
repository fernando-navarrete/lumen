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
}
