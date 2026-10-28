import 'dart:math';

import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/game/rules/bag.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/piece_type.dart';
import 'package:blockfall/game/rules/powerups.dart';
import 'package:blockfall/game/rules/well.dart';
import 'package:blockfall/ui/blockfall_prefs.dart';
import 'package:blockfall/ui/game_screen.dart';
import 'package:blockfall/ui/settings_screen.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/blockfall_bot.dart';
import '../helpers/fake_services.dart';

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
  FakeAdService? ads,
  Services? services,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = services ?? await buildFakeServices(ads: ads);
  if (buttons) {
    await (await BlockfallPrefs.load()).setControls(ControlScheme.buttons);
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

void main() {
  testWidgets('HUD shows all elements and no ad widget', (tester) async {
    final handle = tester.ensureSemantics();
    await openGame(tester, mk());
    for (final k in [
      TestIds.gameWidget,
      TestIds.gameWell,
      TestIds.gameScore,
      TestIds.gameBest,
      TestIds.gameLevel,
      TestIds.gameGoal,
      TestIds.gameHold,
      TestIds.gameHoldPiece,
      TestIds.gameNext(0),
      TestIds.gameNext(1),
      TestIds.gameNext(2),
      TestIds.gameCombo,
      TestIds.gamePause,
      TestIds.gameBack,
      TestIds.gamePowerUpSweep,
      TestIds.gamePowerUpSlow,
      TestIds.gamePowerUpBomb,
      TestIds.gamePowerUpSweepCount,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    expect(semValue(tester, TestIds.gameScore), '0');
    expect(semValue(tester, TestIds.gameLevel), '1');
    expect(semValue(tester, TestIds.gameGoal), '10');
    expect(semValue(tester, TestIds.gameHoldPiece), 'empty');
    expect(semValue(tester, TestIds.gameNext(0)), 'Prong');
    expect(semValue(tester, TestIds.gamePowerUpSweepCount), '1');
    handle.dispose();
  });

  group('touch scheme', () {
    testWidgets('control buttons are absent', (tester) async {
      await openGame(tester, mk());
      for (final k in [
        TestIds.gameCtlLeft,
        TestIds.gameCtlRight,
        TestIds.gameCtlRotate,
        TestIds.gameCtlSoftDrop,
        TestIds.gameCtlHardDrop,
      ]) {
        expect(find.byKey(k), findsNothing);
      }
    });

    testWidgets('tap on the well rotates clockwise', (tester) async {
      final g = mk();
      await openGame(tester, g);
      expect(g.currentPiece!.rotation, 0);
      await tester.tap(find.byKey(TestIds.gameWell));
      await settle(tester, 1);
      expect(g.currentPiece!.rotation, 1);
    });

    testWidgets('drag of three cell widths moves three columns', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g);
      final col = g.currentPiece!.col;
      await tester.drag(
        find.byKey(TestIds.gameWell),
        Offset(3 * wellCell(tester), 0),
      );
      await settle(tester, 1);
      expect(g.currentPiece!.col, col + 3);
      await tester.drag(
        find.byKey(TestIds.gameWell),
        Offset(-2 * wellCell(tester), 0),
      );
      await settle(tester, 1);
      expect(g.currentPiece!.col, col + 1);
      expect(g.currentPiece!.rotation, 0, reason: 'a drag is not a tap');
    });

    testWidgets('slow downward drag soft drops, release stops it', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(TestIds.gameWell)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.isSoftDropping, isTrue);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(g.score, greaterThan(0), reason: 'soft drop scores per row');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.isSoftDropping, isFalse);
    });

    testWidgets('fast fling down hard drops and locks the piece', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g);
      await tester.fling(
        find.byKey(TestIds.gameWell),
        const Offset(0, 300),
        2000,
      );
      await settle(tester, 1);
      expect(g.piecesPlaced, 1);
      expect(g.score, greaterThan(0));
    });

    testWidgets('slow vertical drag does not hard drop', (tester) async {
      final g = mk();
      await openGame(tester, g);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(TestIds.gameWell)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(g.piecesPlaced, 0);
      expect(g.isSoftDropping, isFalse);
    });

    testWidgets('tapping the Hold box holds, a second tap is ignored', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final g = mk(seq: [PieceType.prong, PieceType.boot]);
      await openGame(tester, g);
      await tapKey(tester, TestIds.gameHold);
      expect(g.holdPiece!.type, PieceType.prong);
      expect(semValue(tester, TestIds.gameHoldPiece), 'Prong');
      expect(g.holdsUsed, 1);
      await tapKey(tester, TestIds.gameHold);
      expect(g.holdsUsed, 1);
      handle.dispose();
    });
  });

  group('buttons scheme', () {
    testWidgets('all five buttons exist and work', (tester) async {
      final g = mk(seq: [PieceType.bar]);
      await openGame(tester, g, buttons: true);
      for (final k in [
        TestIds.gameCtlLeft,
        TestIds.gameCtlRight,
        TestIds.gameCtlRotate,
        TestIds.gameCtlSoftDrop,
        TestIds.gameCtlHardDrop,
      ]) {
        expect(find.byKey(k), findsOneWidget, reason: '$k');
      }
      final col = g.currentPiece!.col;
      await tapKey(tester, TestIds.gameCtlLeft);
      expect(g.currentPiece!.col, col - 1);
      await tapKey(tester, TestIds.gameCtlRight);
      await tapKey(tester, TestIds.gameCtlRight);
      expect(g.currentPiece!.col, col + 1);
      await tapKey(tester, TestIds.gameCtlRotate);
      expect(g.currentPiece!.rotation, 1);
      final row = g.currentPiece!.row;
      await tapKey(tester, TestIds.gameCtlSoftDrop);
      expect(g.currentPiece!.row, greaterThan(row));
      await tapKey(tester, TestIds.gameCtlHardDrop);
      expect(g.piecesPlaced, 1);
    });

    testWidgets('touch gestures are off while Buttons is selected', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g, buttons: true);
      await tester.tap(find.byKey(TestIds.gameWell));
      await settle(tester, 1);
      expect(g.currentPiece!.rotation, 0);
    });

    testWidgets('clearing four rows updates score, lines, goal', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final g = mk(seq: [PieceType.bar], rows: List.filled(4, '111111111.'));
      await openGame(tester, g, buttons: true);
      await tapKey(tester, TestIds.gameCtlRotate);
      for (var i = 0; i < 4; i++) {
        await tapKey(tester, TestIds.gameCtlRight);
      }
      await tapKey(tester, TestIds.gameCtlHardDrop);
      expect(g.lines, 4);
      expect(int.parse(semValue(tester, TestIds.gameScore)), g.score);
      expect(g.score, greaterThanOrEqualTo(800));
      expect(semValue(tester, TestIds.gameGoal), '6');
      expect(semValue(tester, TestIds.gameCombo), '1');
      handle.dispose();
    });
  });

  group('power-ups', () {
    testWidgets('Sweep removes rows and uses one from stock', (tester) async {
      final handle = tester.ensureSemantics();
      final g = mk(rows: List.filled(5, '111111111.'));
      await openGame(tester, g);
      await tapKey(tester, TestIds.gamePowerUpSweep);
      expect(g.lines, 3);
      expect(g.stock(PowerUpType.sweep), 0);
      expect(semValue(tester, TestIds.gamePowerUpSweepCount), '0');
      handle.dispose();
    });

    testWidgets('Slow starts the slow timer, Bomb replaces the piece', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g);
      await tapKey(tester, TestIds.gamePowerUpSlow);
      expect(g.slowActive, isTrue);
      await tapKey(tester, TestIds.gamePowerUpBomb);
      expect(g.currentPiece!.isBomb, isTrue);
      expect(g.stock(PowerUpType.bomb), 0);
    });

    testWidgets('stock is saved for the next game', (tester) async {
      final g = mk();
      await openGame(tester, g);
      await tapKey(tester, TestIds.gamePowerUpSlow);
      final prefs = await BlockfallPrefs.load();
      expect(prefs.stock[PowerUpType.slow], 0);
      expect(prefs.stock[PowerUpType.sweep], 1);
    });

    testWidgets('0 stock opens the sheet; coins buy +1 and deduct price', (
      tester,
    ) async {
      final g = mk(stock: {PowerUpType.bomb: 0});
      final s = await openGame(tester, g);
      await s.profile.addCoins(100);
      await tapKey(tester, TestIds.gamePowerUpBomb);
      expect(find.byKey(TestIds.gameRefillCoins), findsOneWidget);
      expect(find.byKey(TestIds.gameRefillAd), findsOneWidget);
      expect(g.isPaused, isTrue, reason: 'the sheet freezes the game');
      await tapKey(tester, TestIds.gameRefillCoins);
      await settle(tester);
      expect(g.stock(PowerUpType.bomb), 1);
      expect(s.profile.data.coins, 50);
      expect(g.isPaused, isFalse);
    });

    testWidgets('buying without enough coins changes nothing', (tester) async {
      final g = mk(stock: {PowerUpType.sweep: 0});
      final s = await openGame(tester, g);
      await tapKey(tester, TestIds.gamePowerUpSweep);
      await tapKey(tester, TestIds.gameRefillCoins);
      await settle(tester);
      expect(g.stock(PowerUpType.sweep), 0);
      expect(s.profile.data.coins, 0);
    });

    testWidgets('ad refill adds +1, at most 3 per game', (tester) async {
      final ads = FakeAdService();
      final g = mk(stock: {PowerUpType.sweep: 0});
      await openGame(tester, g, ads: ads);
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, TestIds.gamePowerUpSweep);
        await tapKey(tester, TestIds.gameRefillAd);
        expect(g.stock(PowerUpType.sweep), 1);
        await tapKey(tester, TestIds.gamePowerUpSweep);
        expect(g.stock(PowerUpType.sweep), 0);
      }
      expect(ads.rewardedShown, 3);
      expect(g.adRefillsLeft, 0);
    });

    testWidgets('a failed rewarded ad grants nothing', (tester) async {
      final ads = FakeAdService(rewardResult: false);
      final g = mk(stock: {PowerUpType.slow: 0});
      await openGame(tester, g, ads: ads);
      await tapKey(tester, TestIds.gamePowerUpSlow);
      await tapKey(tester, TestIds.gameRefillAd);
      expect(g.stock(PowerUpType.slow), 0);
      expect(g.adRefillsUsed, 0);
    });
  });

  group('pause', () {
    testWidgets('pause button shows the overlay, resume continues', (
      tester,
    ) async {
      final g = mk();
      await openGame(tester, g);
      await tapKey(tester, TestIds.gamePause);
      expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
      expect(find.byKey(TestIds.gamePauseQuit), findsOneWidget);
      expect(g.isPaused, isTrue);
      final row = g.currentPiece!.row;
      await settle(tester, 30);
      expect(g.currentPiece!.row, row, reason: 'frozen while paused');
      await tester.tap(find.byKey(TestIds.gameWell), warnIfMissed: false);
      expect(g.currentPiece!.rotation, 0);
      await tapKey(tester, TestIds.gamePauseResume);
      expect(find.byKey(TestIds.gamePauseResume), findsNothing);
      expect(g.isPaused, isFalse);
      await settle(tester, 15);
      expect(g.currentPiece!.row, greaterThan(row));
    });

    testWidgets('going to the background pauses', (tester) async {
      final g = mk();
      await openGame(tester, g);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester, 1);
      expect(g.isPaused, isTrue);
      expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    });

    testWidgets('quit from the pause overlay returns home', (tester) async {
      final g = mk();
      final s = await openGame(tester, g);
      await tapKey(tester, TestIds.gamePause);
      await tapKey(tester, TestIds.gamePauseQuit);
      await settle(tester, 6);
      expect(find.byKey(TestIds.gameWidget), findsNothing);
      expect(s.profile.data.stats.gamesPlayed, 0, reason: 'nothing played');
    });
  });

  group('game over', () {
    BlockfallGame doomed() => mk(rows: List.filled(22, '111111111.'));

    testWidgets('dialog shows score, revive, retry, home', (tester) async {
      final handle = tester.ensureSemantics();
      final g = doomed();
      await openGame(tester, g);
      expect(g.isGameOver, isTrue);
      expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
      expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);
      expect(find.byKey(TestIds.gameOverRetry), findsOneWidget);
      expect(find.byKey(TestIds.gameOverHome), findsOneWidget);
      expect(semValue(tester, TestIds.gameOverScore), '0');
      expect(find.byKey(TestIds.gameBanner), findsNothing);
      handle.dispose();
    });

    testWidgets('revive watches a rewarded ad and continues the game', (
      tester,
    ) async {
      final ads = FakeAdService();
      final g = doomed();
      await openGame(tester, g, ads: ads);
      await tapKey(tester, TestIds.gameOverRevive);
      await settle(tester);
      expect(ads.rewardedShown, 1);
      expect(g.isGameOver, isFalse);
      expect(g.reviveUsed, isTrue);
      expect(find.byKey(TestIds.gameOverDialog), findsNothing);
    });

    testWidgets('a failed ad keeps the dialog open', (tester) async {
      final ads = FakeAdService(rewardResult: false);
      final g = doomed();
      await openGame(tester, g, ads: ads);
      await tapKey(tester, TestIds.gameOverRevive);
      await settle(tester);
      expect(g.isGameOver, isTrue);
      expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    });

    testWidgets('play again records the game and starts a fresh one', (
      tester,
    ) async {
      final g = doomed();
      final s = await openGame(tester, g);
      await tapKey(tester, TestIds.gameOverRetry);
      await settle(tester);
      expect(s.profile.data.stats.gamesPlayed, 1);
      expect(find.byKey(TestIds.gameOverDialog), findsNothing);
      expect(find.byKey(TestIds.gameWell), findsOneWidget);
    });

    testWidgets('home records the game and leaves the screen', (tester) async {
      final g = doomed();
      final s = await openGame(tester, g);
      await tapKey(tester, TestIds.gameOverHome);
      await settle(tester, 6);
      expect(s.profile.data.stats.gamesPlayed, 1);
      expect(find.byKey(TestIds.gameWidget), findsNothing);
    });
  });

  testWidgets('settings: controls and ghost toggles persist', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await buildFakeServices();
    await tester.pumpWidget(
      ServicesScope(
        services: s,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsControls));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsGhost));
    await tester.pumpAndSettle();
    final p = await BlockfallPrefs.load();
    expect(p.controls, ControlScheme.buttons);
    expect(p.ghost, isFalse);
  });

  testWidgets('bot plays random drops with the buttons until game over', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final g = BlockfallGame.seeded(5);
    await openGame(tester, g, buttons: true);
    final bot = BlockfallBot(tester, seed: 3);
    final dropped = await bot.playRandom(60);
    expect(dropped, greaterThan(5));
    expect(g.piecesPlaced, greaterThan(5));
    if (!bot.isGameOver) {
      expect(bot.score, g.score);
      expect(bot.level, g.level);
    }
    handle.dispose();
  });

  testWidgets('bot drives the touch gestures', (tester) async {
    final g = mk();
    await openGame(tester, g);
    final bot = BlockfallBot(tester);
    await bot.tapWell();
    expect(g.currentPiece!.rotation, 1);
    final col = g.currentPiece!.col;
    await bot.dragColumns(-2);
    expect(g.currentPiece!.col, col - 2);
    await bot.flingDown();
    expect(g.piecesPlaced, 1);
  });
}
