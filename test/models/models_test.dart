import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/models/downloadable_product.dart';
import 'package:lumen/models/game_build.dart';
import 'package:lumen/models/install_size.dart';
import 'package:lumen/models/proton_release.dart';

void main() {
  group('GameBuild', () {
    const a = GameBuild(
      buildId: '1',
      versionName: '1.0',
      releaseDate: '2024-01-01',
      releaseDateTimestamp: 1704067200,
    );
    const b = GameBuild(
      buildId: '1',
      versionName: '1.0',
      releaseDate: '2024-01-01',
      releaseDateTimestamp: 1704067200,
    );
    const c = GameBuild(
      buildId: '2',
      versionName: '1.1',
      releaseDate: '2024-02-01',
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

  group('DownloadableProduct', () {
    const a = DownloadableProduct(id: 1, name: 'Game', productType: 'GAME');
    const b = DownloadableProduct(id: 1, name: 'Game', productType: 'GAME');
    const c = DownloadableProduct(id: 2, name: 'DLC', productType: 'DLC');

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
