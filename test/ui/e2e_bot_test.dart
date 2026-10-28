import 'package:blockfall/app.dart';
import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/blockfall_bot.dart';
import '../helpers/blockfall_scenario.dart';
import '../helpers/fake_services.dart';
import '../helpers/game_harness.dart';

/// Plays one seeded game end to end through the real game screen, like the emulator
/// integration test does, and returns (final score, pieces dropped, lines).
Future<({int score, int pieces, int lines})> playSeeded(
  WidgetTester tester,
  int seed,
) async {
  await tester.pumpWidget(const SizedBox.shrink()); // fresh Navigator per game
  final g = BlockfallGame.seeded(seed);
  final s = await openGame(tester, g, buttons: true, ads: FakeAdService());
  final bot = BlockfallBot(tester, seed: seed);

  await BlockfallScenario.openingMoves(tester, bot, rules: g);
  final dropped = await BlockfallScenario.playToGameOver(tester, bot);

  // A valid game-over state.
  expect(g.isGameOver, isTrue);
  expect(g.gameOverReason, isNotNull);
  expect(g.score, greaterThan(0));
  expect(g.level, g.lines ~/ 10 + 1);
  expect(g.coinsFromPrisms, inInclusiveRange(0, 40));
  expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
  await settle(tester, 2);
  expect(semValue(tester, TestIds.gameOverScore), '${g.score}');

  // Leaving records the game once.
  await tapKey(tester, TestIds.gameOverHome);
  await settle(tester, 6);
  expect(find.byKey(TestIds.gameWidget), findsNothing);
  final stats = s.profile.data.stats;
  expect(stats.gamesPlayed, 1);
  expect(stats.piecesPlaced, g.piecesPlaced);
  expect(stats.totalLines, g.lines);
  expect(s.profile.data.bestScore, g.score);
  expect(stats.maxLevel, g.level);
  expect(stats.quads, g.quads);
  expect(stats.holdsUsed, g.holdsUsed);
  expect(tester.takeException(), isNull);
  return (score: g.score, pieces: dropped, lines: g.lines);
}

void main() {
  testWidgets(
    'whole app: Home, gestures, buttons, power-up, pause, game over, Home',
    (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await buildFakeServices();
      await tester.pumpWidget(GameApp(services: s));
      await tester.pump(const Duration(milliseconds: 300));
      await BlockfallScenario.fullAppRun(tester);
      expect(s.profile.data.stats.gamesPlayed, 2);
      expect(s.profile.data.controls, ControlScheme.buttons);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets(
    'seeded bot game: opening moves, a few hundred ticks, game over',
    (tester) async {
      final handle = tester.ensureSemantics();
      final r = await playSeeded(tester, 7);
      expect(r.pieces, greaterThan(10));
      handle.dispose();
    },
  );

  testWidgets('the same seed and the same bot give the same game', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final a = await playSeeded(tester, 11);
    final b = await playSeeded(tester, 11);
    expect(b.score, a.score);
    expect(b.pieces, a.pieces);
    expect(b.lines, a.lines);
    handle.dispose();
  });
}
