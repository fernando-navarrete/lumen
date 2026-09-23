import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/state/home_state.dart';

import '../helpers/container.dart';

void main() {
  group('NavBarNotifier', () {
    test('defaults to library', () async {
      final container = await createContainer();
      expect(container.read(navBarItemProvider), NavBarItem.library);
    });

    test('select updates the state each time', () async {
      final container = await createContainer();
      final notifier = container.read(navBarItemProvider.notifier);

      notifier.select(NavBarItem.downloads);
      expect(container.read(navBarItemProvider), NavBarItem.downloads);

      notifier.select(NavBarItem.settings);
      expect(container.read(navBarItemProvider), NavBarItem.settings);
    });

    test(
      'a listener sees each change once, and reselecting the same item '
      'sends no notification',
      () async {
        final container = await createContainer();
        final notifier = container.read(navBarItemProvider.notifier);
        final seen = <NavBarItem>[];
        container.listen(
          navBarItemProvider,
          (previous, next) => seen.add(next),
          fireImmediately: false,
        );

        notifier.select(NavBarItem.downloads);
        notifier.select(NavBarItem.downloads);
        notifier.select(NavBarItem.settings);

        expect(seen, [NavBarItem.downloads, NavBarItem.settings]);
      },
    );
  });
}
