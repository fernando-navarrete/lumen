import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/nav_bar.dart';
import 'package:lumen/state/home_state.dart';

import '../helpers/pump_app.dart';

/// Widget test deferred from Phase 7 (blocked on font stubbing, now added
/// in `test/flutter_test_config.dart`).
void main() {
  testWidgets('tapping a tab updates navBarItemProvider', (tester) async {
    final container = await pumpApp(tester, const NavBar());

    expect(container.read(navBarItemProvider), NavBarItem.library);

    await tester.tap(find.text('Downloads'));
    await tester.pump();

    expect(container.read(navBarItemProvider), NavBarItem.downloads);
  });
}
