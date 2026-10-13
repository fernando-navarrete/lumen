import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/components/game_card.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('a game card opens from the keyboard with Tab and Enter', (
    tester,
  ) async {
    var opened = 0;
    await pumpApp(
      tester,
      SizedBox(
        width: 200,
        height: 300,
        child: GameCard(gameId: 1, gameName: 'Alpha', onTap: () => opened++),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 1);
  });
}
