import 'dart:math';

import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/game/rules/bag.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/piece_type.dart';
import 'package:blockfall/game/rules/powerups.dart';
import 'package:blockfall/game/rules/well.dart';
import 'package:blockfall/ui/game_screen.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_services.dart';

/// Game with a repeating piece sequence and no prisms.
BlockfallGame mk({
  List<PieceType> seq = const [PieceType.prong],
  List<String> rows = const [],
  Map<PowerUpType, int>? stock,
}) => BlockfallGame(
  random: Random(1),
  bag: PieceBag.sequence(seq),
  well: Well.fromRows(rows),
  prismInterval: 0,
  stock: stock,
);

/// Pumps fixed durations (the Flame loop never settles).
Future<void> settle(WidgetTester tester, [int frames = 4]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<Services> openGame(
  WidgetTester tester,
  BlockfallGame game, {
  bool buttons = false,
  AdService? ads,
  Services? services,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = services ?? await buildFakeServices(ads: ads);
  if (buttons) {
    await s.profile.setControls(ControlScheme.buttons);
  }
  await tester.pumpWidget(
    ServicesScope(
      services: s,
      child: MaterialApp(home: GameScreen(game: game)),
    ),
  );
  await settle(tester);
  return s;
}

String semValue(WidgetTester tester, Key k) =>
    tester.getSemantics(find.byKey(k)).value;

double wellCell(WidgetTester tester) =>
    (tester.getSize(find.byKey(TestIds.gameWell)).width - 12) / 10;

Future<void> tapKey(WidgetTester tester, Key k) async {
  await tester.tap(find.byKey(k));
  await settle(tester, 4);
}
