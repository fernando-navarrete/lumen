import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/install_space_dialog.dart';
import 'package:lumen/models/install_size.dart';

void main() {
  const size = InstallSize(downloadBytes: 50, diskBytes: 100);

  test('unknown when either figure is missing', () {
    expect(installSpaceVerdict(null, 1000), InstallSpaceVerdict.unknown);
    expect(installSpaceVerdict(size, null), InstallSpaceVerdict.unknown);
  });

  test('insufficient only when disk bytes exceed free space', () {
    expect(installSpaceVerdict(size, 99), InstallSpaceVerdict.insufficient);
    expect(installSpaceVerdict(size, 100), InstallSpaceVerdict.tight);
  });

  test('tight below 5% headroom, fits from there', () {
    expect(installSpaceVerdict(size, 104), InstallSpaceVerdict.tight);
    expect(installSpaceVerdict(size, 105), InstallSpaceVerdict.fits);
    expect(installSpaceVerdict(size, 5000), InstallSpaceVerdict.fits);
  });
}
