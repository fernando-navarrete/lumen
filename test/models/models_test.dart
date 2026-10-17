import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/game_links.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/models/product_removal.dart';
import 'package:lumen/models/proton_release.dart';
import 'package:lumen/models/proton_release_page.dart';

void main() {
  group('GameLinks', () {
    test('equal values are ==, with matching hashCode', () {
      const a = GameLinks(boxart: 'b', background: 'g');
      const b = GameLinks(boxart: 'b', background: 'g');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const GameLinks(boxart: 'b', background: 'x'))));
      expect(GameLinks.empty, const GameLinks(boxart: '', background: ''));
    });
  });

  group('ProtonReleasePage', () {
    const r = ProtonRelease(tagName: 'GE', downloadSize: 1);

    test('equal values are ==, with matching hashCode', () {
      final a = ProtonReleasePage(releases: [r], hasMore: true);
      final b = ProtonReleasePage(releases: [r], hasMore: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(equals(ProtonReleasePage(releases: [r], hasMore: false))),
      );
      expect(
        a,
        isNot(equals(const ProtonReleasePage(releases: [], hasMore: true))),
      );
    });
  });

  group('GameBuild', () {
    const a = GameBuild(
      buildId: '1',
      versionName: '1.0',
      releaseDateTimestamp: 1704067200,
    );
    const b = GameBuild(
      buildId: '1',
      versionName: '1.0',
      releaseDateTimestamp: 1704067200,
    );
    const c = GameBuild(
      buildId: '2',
      versionName: '1.1',
      releaseDateTimestamp: 1706745600,
    );

    test('equal values are ==, with matching hashCode', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing values are not ==', () {
      expect(a, isNot(equals(c)));
    });
  });

  group('InstallSize', () {
    const a = InstallSize(downloadBytes: 10, diskBytes: 25);
    const b = InstallSize(downloadBytes: 10, diskBytes: 25);
    const c = InstallSize(downloadBytes: 10, diskBytes: 26);

    test('equal values are ==, with matching hashCode', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing values are not ==', () {
      expect(a, isNot(equals(c)));
    });
  });

  group('ProductRemoval', () {
    const a = ProductRemoval(filesRemoved: 3, bytesFreed: 100);
    const b = ProductRemoval(filesRemoved: 3, bytesFreed: 100);
    const c = ProductRemoval(filesRemoved: 3, bytesFreed: 101);

    test('equal values are ==, with matching hashCode', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing values are not ==', () {
      expect(a, isNot(equals(c)));
    });
  });

  group('DownloadableProduct', () {
    const a = DownloadableProduct(
      id: 1,
      name: 'Game',
      productType: ProductType.game,
    );
    const b = DownloadableProduct(
      id: 1,
      name: 'Game',
      productType: ProductType.game,
    );
    const c = DownloadableProduct(
      id: 2,
      name: 'DLC',
      productType: ProductType.dlc,
    );

    test('equal values are ==, with matching hashCode', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing values are not ==', () {
      expect(a, isNot(equals(c)));
    });
  });

  group('ProtonRelease', () {
    const a = ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 12345);
    const b = ProtonRelease(tagName: 'GE-Proton9-1', downloadSize: 12345);
    const c = ProtonRelease(tagName: 'GE-Proton9-2', downloadSize: 54321);

    test('equal values are ==, with matching hashCode', () {
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing values are not ==', () {
      expect(a, isNot(equals(c)));
    });
  });
}
