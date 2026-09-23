import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/format.dart';

void main() {
  group('formatBytes', () {
    test('zero bytes', () {
      expect(formatBytes(0), '0 B');
    });

    test('stays in bytes just under 1 KB', () {
      expect(formatBytes(1023), '1023 B');
    });

    test('rounds to one decimal once it crosses a unit boundary', () {
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1536), '1.5 KB');
    });

    test('scales up through GB', () {
      expect(formatBytes(1024 * 1024 * 1024), '1.0 GB');
    });

    test('caps out at TB rather than inventing a larger unit', () {
      final oneThousandTb = 1024 * 1024 * 1024 * 1024 * 1024; // 1024 TB
      expect(formatBytes(oneThousandTb), '1024.0 TB');
    });
  });
}
