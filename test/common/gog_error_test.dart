import 'package:flutter_test/flutter_test.dart';
import 'package:gogdl_flutter/gogdl_flutter.dart';
import 'package:lumen/common/gog_error.dart';

/// Stands in for the opaque native `GogError`, so no native library loads.
class _FakeGogError extends Fake implements GogError {
  _FakeGogError(this._kind, {this.shortfall});

  final GogErrorKind _kind;
  final SpaceShortfall? shortfall;

  @override
  GogErrorKind kind() => _kind;

  @override
  SpaceShortfall? spaceShortfall() => shortfall;

  @override
  String message() => 'raw message';
}

void main() {
  group('jobErrorText', () {
    test('not enough space names the numbers when the bridge has them', () {
      final text = jobErrorText(
        _FakeGogError(
          GogErrorKind.notEnoughSpace,
          shortfall: SpaceShortfall(
            requiredBytes: BigInt.from(2) * BigInt.from(1024 * 1024 * 1024),
            availableBytes: BigInt.from(1024 * 1024 * 1024),
          ),
        ),
      );

      expect(text, startsWith('Not enough disk space: needs '));
      expect(text, contains('2.0 GB'));
      expect(text, contains('1.0 GB'));
    });

    test('not enough space without a shortfall', () {
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.notEnoughSpace)),
        'Not enough disk space',
      );
    });

    test('kinds the user can act on get Lumen wording', () {
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.network)),
        contains('Network error'),
      );
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.sessionExpired)),
        contains('session expired'),
      );
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.notFound)),
        contains('no longer available'),
      );
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.integrity)),
        contains('corrupt'),
      );
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.fileSystem)),
        contains('install folder'),
      );
    });

    test('unknown kinds keep the bridge message', () {
      expect(jobErrorText(_FakeGogError(GogErrorKind.unknown)), 'raw message');
      expect(
        jobErrorText(_FakeGogError(GogErrorKind.cloudSavesUnsupported)),
        'raw message',
      );
    });

    test('anything that is not a GogError falls back to toString', () {
      expect(jobErrorText(Exception('boom')), 'Exception: boom');
    });
  });
}
