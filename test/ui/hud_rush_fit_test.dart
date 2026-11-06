import 'package:blockfall/game/rules/piece_type.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/game_harness.dart';

void main() {
  testWidgets('HUD: streak, combo and Gold Rush chip fit at 360 wide', (
    tester,
  ) async {
    // A golden block clears: Gold Rush starts and the combo is 1.
    final g = mk(rows: ['11H....111'], seq: [PieceType.bar]);
    g.well.set(10, 0, 2);
    g.hardDrop();
    await openGame(tester, g);
    tester.view.physicalSize = const Size(360, 640);
    await settle(tester);
    expect(find.byKey(TestIds.gameRush), findsOneWidget);
    expect(find.textContaining('GOLD RUSH'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
