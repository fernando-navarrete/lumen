import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/side_column_layout.dart';
import 'package:lumen/screens/home/pages/library/overview_tab.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// `v1.4.2`: screenshots are cropped, not stretched, and decoded at the size
/// they're shown rather than at full resolution.
void main() {
  testWidgets('a screenshot uses BoxFit.cover and decodes at its cell width', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..screenshots[1] = ['https://example.invalid/shot.jpg'];
    await pumpApp(tester, const OverviewTab(gameId: 1), backend: backend);
    await tester.pump();
    await tester.pump();

    final finder = find.byType(Image);
    expect(finder, findsOneWidget);
    final image = tester.widget<Image>(finder);
    expect(image.fit, BoxFit.cover);

    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final expected =
        (tester.getSize(finder).width * tester.view.devicePixelRatio).ceil();
    expect((provider as ResizeImage).width, expected);
  });

  group('side column', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      await pumpApp(
        tester,
        const OverviewTab(gameId: 1),
        backend: FakeGogBackend(),
        surfaceSize: Size(width, 900),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('is hidden in a narrow tab', (tester) async {
      await pumpAt(tester, 560);
      expect(find.byKey(SideColumnLayout.sideKey), findsNothing);
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('is 280 wide in a medium tab', (tester) async {
      await pumpAt(tester, 1000);
      expect(tester.getSize(find.byKey(SideColumnLayout.sideKey)).width, 280);
    });

    testWidgets('is 340 wide in a wide tab', (tester) async {
      await pumpAt(tester, 1600);
      expect(tester.getSize(find.byKey(SideColumnLayout.sideKey)).width, 340);
      expect(find.text('Status'), findsOneWidget);
    });
  });
}
