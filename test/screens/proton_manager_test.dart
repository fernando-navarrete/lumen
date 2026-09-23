import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/screens/home/pages/settings/proton_manager.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// Regression `v1.1.2`: the Proton releases dialog distinguishes a failed
/// fetch (shows an error + Retry) from a merely-empty page (shows "No
/// releases available", no Retry), instead of showing "No releases loaded"
/// with an endless "Load more" for both.
void main() {
  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Manage / install versions…'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a failed fetch shows an error and a Retry button', (
    tester,
  ) async {
    final backend = FakeGogBackend()
      ..throwOn['getProtonReleases'] = Exception('boom');

    await pumpApp(tester, const ProtonManagerSection(), backend: backend);
    await openDialog(tester);

    expect(find.text("Couldn't load releases"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets(
    'tapping Retry after clearing the failure re-fetches the same page',
    (tester) async {
      final backend = FakeGogBackend()
        ..throwOn['getProtonReleases'] = Exception('boom');

      await pumpApp(tester, const ProtonManagerSection(), backend: backend);
      await openDialog(tester);

      backend.throwOn.clear();
      backend.protonReleases = [
        const ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000),
      ];

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('GE-Proton9-1'), findsOneWidget);
      final calls = backend.callsTo('getProtonReleases');
      expect(calls, hasLength(2));
      expect(calls[0].args['page'], 1);
      expect(calls[1].args['page'], 1);
    },
  );

  testWidgets(
    'an empty page shows "No releases available" with no Load more button',
    (tester) async {
      final backend = FakeGogBackend()..protonReleases = [];

      await pumpApp(tester, const ProtonManagerSection(), backend: backend);
      await openDialog(tester);

      expect(find.text('No releases available'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('a non-empty page shows Load more, not an error', (tester) async {
    final backend = FakeGogBackend()
      ..protonReleases = [
        const ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 1000),
      ];

    await pumpApp(tester, const ProtonManagerSection(), backend: backend);
    await openDialog(tester);

    expect(find.text('GE-Proton9-1'), findsOneWidget);
    expect(find.text('Load more'), findsOneWidget);
  });
}
