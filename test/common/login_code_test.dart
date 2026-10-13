import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/login_code.dart';

void main() {
  group('extractLoginCode', () {
    test('a bare code is returned as is', () {
      expect(extractLoginCode('M0xY7abc'), 'M0xY7abc');
    });

    test('surrounding whitespace is trimmed', () {
      expect(extractLoginCode('  M0xY7abc\n'), 'M0xY7abc');
    });

    test('a full redirect URL gives its code', () {
      expect(
        extractLoginCode(
          'https://embed.gog.com/on_login_success?origin=client&code=XYZ',
        ),
        'XYZ',
      );
    });

    test('a code parameter followed by others stops at the ampersand', () {
      expect(extractLoginCode('code=XYZ&state=1'), 'XYZ');
    });

    test('code= alone', () {
      expect(extractLoginCode('code=XYZ'), 'XYZ');
    });

    test('empty input stays empty', () {
      expect(extractLoginCode('   '), '');
    });
  });
}
