import 'dart:math';

import 'package:blockfall/app.dart';
import 'package:blockfall/core/profile/profile_store.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/core/share/share_service.dart';
import 'package:blockfall/game/rules/bag.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/piece_type.dart';
import 'package:blockfall/game/rules/well.dart';
import 'package:blockfall/game/themes/block_theme.dart';
import 'package:blockfall/ui/share_card.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/game_harness.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

BlockfallGame doomed() => mk(rows: List.filled(22, '111111111.'));

void main() {
  testWidgets('share card renders to a non-empty PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: ShareCard(
            data: ShareCardData(
              gameName: 'Block Fall',
              headline: 'Score',
              big: '42',
              best: 99,
              theme: BlockTheme.cakes,
            ),
          ),
        ),
      ),
    );
    final bytes = await tester.runAsync(
      () => boundaryToPng(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
      ),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('settings.shareApp is hidden while the link flag is off', (
    tester,
  ) async {
    final s = await buildFakeServices();
    expect(s.config.share.appLinkEnabled, isFalse);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    expect(
      find.byKey(TestIds.settingsShareApp, skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(TestIds.settingsTips, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('achievement share icon shares the achievement text', (
    tester,
  ) async {
    final share = FakeShareService();
    final s = await buildFakeServices(share: share);
    await s.profile.recordGameFinished(
      const GameSummary(
        score: 100,
        linesCleared: 1,
        piecesPlaced: 5,
        maxCombo: 1,
      ),
    );
    expect(s.profile.data.unlockedAchievements, contains('ach_first_row'));
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeChallenges));
    await tester.pumpAndSettle();
    final btn = find.byKey(TestIds.achievementShare('ach_first_row'));
    await tester.scrollUntilVisible(btn, 100);
    expect(
      find.byKey(TestIds.achievementShare('ach_ach_missing')),
      findsNothing,
    );
    await tester.tap(btn);
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I unlocked "'));
  });

  testWidgets('game over share button shares the score text', (tester) async {
    final share = FakeShareService();
    final s = await buildFakeServices(share: share);
    await s.profile.setSound(false);
    await openGame(tester, doomed(), services: s);
    expect(find.byKey(TestIds.gameOverShare), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverShare));
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I scored '));
    expect(share.sent.single.text, isNot(contains('http')));
  });

  testWidgets('home tip shows once per day and closing keeps it hidden', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsNothing);
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    await tester.pump();
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.hintDue('prism'), isFalse);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final sw = find.byKey(TestIds.settingsTips);
    await tester.scrollUntilVisible(sw, 100);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
    expect(s.profile.hintDue('prism'), isTrue);
  });

  testWidgets('game over tip shows on every 2nd game over', (tester) async {
    final s = await buildFakeServices(tips: true);
    for (final id in ['prism', 'boom', 'gold', 'rush']) {
      await s.profile.markHintSeen(id);
    }
    await openGame(tester, doomed(), services: s);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
    expect(find.byKey(TestIds.gameOverRevive), findsOneWidget);
  });

  testWidgets('game over tip: second game over of a session shows it', (
    tester,
  ) async {
    final s = await buildFakeServices(tips: true);
    for (final id in ['prism', 'boom', 'gold', 'rush']) {
      await s.profile.markHintSeen(id);
    }
    final first = doomed();
    await openGame(tester, first, services: s);
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
    // Play again starts a fresh seeded-less game; make it end at once by dropping pieces.
    await tapKey(tester, TestIds.gameOverRetry);
    await settle(tester);
    // Stack pieces straight down until the new game ends.
    final screen = find.byKey(TestIds.gameWidget);
    expect(screen, findsOneWidget);
    for (var i = 0; i < 80; i++) {
      if (find.byKey(TestIds.gameOverDialog).evaluate().isNotEmpty) break;
      await tester.fling(
        find.byKey(TestIds.gameWell),
        const Offset(0, 400),
        3000,
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    await settle(tester);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipGameOver), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    expect(find.byKey(TestIds.tipGameOver), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
  });

  testWidgets('pause tip appears only after 3 seconds', (tester) async {
    final s = await buildFakeServices(tips: true);
    for (final id in ['prism', 'boom', 'gold', 'rush']) {
      await s.profile.markHintSeen(id);
    }
    await openGame(tester, mk(), services: s);
    await tapKey(tester, TestIds.gamePause);
    expect(find.byKey(TestIds.gamePauseResume), findsOneWidget);
    expect(find.byKey(TestIds.tipPause), findsNothing);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byKey(TestIds.tipPause), findsNothing);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.tipPause), findsOneWidget);
  });

  testWidgets('one-time hint shows once, for 4 s', (tester) async {
    final s = await buildFakeServices(tips: true);
    final g = BlockfallGame(
      random: Random(1),
      bag: PieceBag.sequence(const [PieceType.prong]),
      well: Well.fromRows(const []),
      prismInterval: 2,
      boomInterval: 0,
      goldInterval: 0,
    );
    await openGame(tester, g, services: s);
    // The prism arrives with the 2nd piece; drop pieces until the hint shows.
    for (var i = 0; i < 4 && s.profile.hintDue('prism'); i++) {
      g.hardDrop();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(s.profile.hintDue('prism'), isFalse);
    expect(find.byKey(TestIds.tipHint), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(TestIds.tipHint), findsNothing);
    // Never again.
    for (var i = 0; i < 4; i++) {
      g.hardDrop();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(TestIds.tipHint), findsNothing);
  });
}
