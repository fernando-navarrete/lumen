import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/screens/home/pages/library/library_page.dart';

import '../helpers/fake_gog_backend.dart';
import '../helpers/pump_app.dart';

/// Regression `v1.0.6`: the Library page shows an error/empty state with a
/// Retry, instead of spinning forever.
void main() {
  testWidgets(
    'a failed getOwnedGames shows an error message with Retry',
    (tester) async {
      final backend = FakeGogBackend()
        ..throwOn['getOwnedGames'] = Exception('boom');

      await pumpApp(tester, const LibraryPage(), backend: backend);
      await tester.pump(); // run the post-frame callback that starts _load
      await tester.pump(); // let the failed future resolve

      expect(find.text("Couldn't load your library."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('an empty library shows an empty-state message with Retry', (
    tester,
  ) async {
    final backend = FakeGogBackend()..ownedGames = [];

    await pumpApp(tester, const LibraryPage(), backend: backend);
    await tester.pump();
    await tester.pump();

    expect(find.text('No games in your library.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'tapping Retry after clearing the failure loads the library',
    (tester) async {
      final backend = FakeGogBackend()
        ..throwOn['getOwnedGames'] = Exception('boom');

      await pumpApp(tester, const LibraryPage(), backend: backend);
      await tester.pump();
      await tester.pump();

      expect(find.text("Couldn't load your library."), findsOneWidget);

      backend.throwOn.clear();
      backend.ownedGames = [1];
      backend.titles[1] = 'A Great Game';

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(); // getOwnedGames resolves
      await tester.pump(); // per-game getGameName resolves

      expect(find.text('A Great Game'), findsWidgets);
      expect(backend.callsTo('getOwnedGames'), hasLength(2));
    },
  );
}
