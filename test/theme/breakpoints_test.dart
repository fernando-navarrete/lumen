import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/theme/breakpoints.dart';

void main() {
  test('hidden below the compact breakpoint', () {
    expect(sideColumnWidth(0), 0);
    expect(sideColumnWidth(599.9), 0);
  });

  test('regular width from compact up to and including wide', () {
    expect(sideColumnWidth(600), SideColumn.regular);
    expect(sideColumnWidth(1000), SideColumn.regular);
    expect(sideColumnWidth(1200), SideColumn.regular);
  });

  test('wide width above the wide breakpoint', () {
    expect(sideColumnWidth(1200.1), SideColumn.wide);
    expect(sideColumnWidth(2000), SideColumn.wide);
  });
}
