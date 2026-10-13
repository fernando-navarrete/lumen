import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/common/clickable_container.dart';
import 'package:lumen/theme/app_colors.dart';

import '../helpers/pump_app.dart';

Finder get _ring => find.descendant(
  of: find.byType(ClickableContainer),
  matching: find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.position == DecorationPosition.foreground &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  ),
);

void main() {
  Widget box({VoidCallback? onTap, String? label}) => Center(
    child: ClickableContainer(
      onTap: onTap,
      semanticLabel: label,
      child: const SizedBox(width: 80, height: 40, child: Text('go')),
    ),
  );

  testWidgets('Tab focuses it; Enter and Space call onTap', (tester) async {
    var taps = 0;
    await pumpApp(tester, box(onTap: () => taps++));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
  });

  testWidgets('a null onTap is not focusable and ignores taps', (tester) async {
    await pumpApp(tester, box());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ring, findsNothing);
    expect(Focus.of(tester.element(find.text('go'))).hasFocus, isFalse);

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(_ring, findsNothing);
  });

  testWidgets('a mouse click does not show the focus ring', (tester) async {
    var taps = 0;
    await pumpApp(tester, box(onTap: () => taps++));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(taps, 1);
    expect(_ring, findsNothing);
  });

  testWidgets('the ring is teal', (tester) async {
    await pumpApp(tester, box(onTap: () {}));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final decoration =
        (tester.widget<DecoratedBox>(_ring).decoration as BoxDecoration);
    expect(decoration.border!.top.color, AppColors.primary);
  });

  testWidgets('exposes a labeled button; disabled reports not enabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, box(onTap: () {}, label: 'Remove variable'));
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Remove variable'))),
      matchesSemantics(
        label: 'Remove variable\ngo',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );

    await pumpApp(tester, box(label: 'Remove variable'));
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Remove variable'))),
      matchesSemantics(
        label: 'Remove variable\ngo',
        isButton: true,
        hasEnabledState: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
