import 'dart:async';

import 'package:blockfall/app.dart';
import 'package:blockfall/core/profile/profile_store.dart';
import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/core/save/save_service.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/core/share/share_service.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/themes/block_theme.dart';
import 'package:blockfall/ui/game_screen.dart';
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
  await tester.pump(const Duration(milliseconds: 400));
}

/// Save service whose `save` waits until [release] is called (a slow disk write).
class _GatedSaveService extends MemorySaveService {
  final _gate = Completer<void>();
  bool gated = false;
  void release() => _gate.complete();

  @override
  Future<void> save(SaveData d) async {
    if (gated) await _gate.future;
    await super.save(d);
  }
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

  testWidgets('settings.shareApp is shown in internal_test mode and shares '
      'the message with the link', (tester) async {
    final share = FakeShareService(link: 'https://example.com/t');
    final s = await buildFakeServices(share: share);
    expect(s.config.shareLink, isNotNull);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final tile = find.byKey(TestIds.settingsShareApp, skipOffstage: false);
    expect(tile, findsOneWidget);
    expect(
      find.byKey(TestIds.settingsTips, skipOffstage: false),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.byKey(TestIds.settingsShareApp), 100);
    await tester.tap(find.byKey(TestIds.settingsShareApp));
    await tester.pump();
    expect(share.sent.single.text, 'Try Block Fall!\nhttps://example.com/t');
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
    await tester.tap(btn);
    await tester.runAsync(() async {
      for (var i = 0; i < 20 && share.sent.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(share.sent, hasLength(1));
    expect(share.sent.single.text, startsWith('I unlocked "'));
    expect(share.sent.single.text, endsWith('Can you beat it?'));
  });

  testWidgets('game over share button shares the score text and link', (
    tester,
  ) async {
    final share = FakeShareService(link: 'https://example.com/t');
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
    expect(
      share.sent.single.text,
      startsWith('This is my high score in Block Fall: '),
    );
    expect(share.sent.single.text, endsWith('\nhttps://example.com/t'));
  });

  testWidgets('game over panel: layout order and view board toggle', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await s.profile.setSound(false);
    await openGame(tester, doomed(), services: s);
    final panel = find.byKey(TestIds.gameOverPanel);
    expect(panel, findsOneWidget);
    final share = tester.getTopLeft(find.byKey(TestIds.gameOverShare));
    final score = tester.getTopLeft(find.byKey(TestIds.gameOverScore));
    final retry = tester.getTopLeft(find.byKey(TestIds.gameOverRetry));
    final home = tester.getTopLeft(find.byKey(TestIds.gameOverHome));
    final cont = tester.getTopLeft(find.byKey(TestIds.gameOverRevive));
    expect(share.dy, lessThan(score.dy));
    expect(share.dx, lessThan(tester.getCenter(panel).dx));
    expect(score.dy, lessThan(retry.dy));
    expect(
      tester.getCenter(find.byKey(TestIds.gameOverRetry)).dy,
      closeTo(tester.getCenter(find.byKey(TestIds.gameOverHome)).dy, 1),
    );
    expect(retry.dx, lessThan(home.dx));
    expect(home.dy, lessThan(cont.dy));

    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: panel, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(), 1);
    await tester.tap(find.byKey(TestIds.gameOverView));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);
    expect(find.byKey(TestIds.gameOverView), findsOneWidget);
    // A tap anywhere brings it back.
    await tester.tapAt(const Offset(200, 700));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
    // The eye button toggles too.
    await tester.tap(find.byKey(TestIds.gameOverView));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 0);
    await tester.tap(find.byKey(TestIds.gameOverView));
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
  });

  testWidgets('home tip is a dialog once per day and closing keeps it away', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.tipsEnabled, isTrue);
    // Home shown again the same day (fresh screen): no dialog.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    // Next day: the dialog opens again.
    now = DateTime.utc(2026, 11, 6, 10);
    await s.profile.onAppOpened();
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsOneWidget);
  });

  testWidgets('no home tip dialog while tips are off', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('ticking the checkbox turns tips off; the settings switch '
      'brings them back', (tester) async {
    final s = await buildFakeServices(tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipDontShow));
    await tester.pump();
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.profile.tipsEnabled, isFalse);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(s.profile.homeTipPending, isFalse);

    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    final sw = find.byKey(TestIds.settingsTips);
    await tester.scrollUntilVisible(sw, 100);
    expect(tester.widget<SwitchListTile>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(s.profile.tipsEnabled, isTrue);
  });

  testWidgets('no tip while a run is on screen: resume with the game on top', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final s = await buildFakeServices(clock: () => now, tips: true);
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.tipClose));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(TestIds.homePlay));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameScreen), findsOneWidget);
    expect(s.inRun, isTrue);
    now = DateTime.utc(2026, 11, 6, 10);
    expect(s.profile.homeTipPending, isTrue);
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(TestIds.tipHome), findsNothing);
  });

  testWidgets('no tip when Play is tapped while the tip is still being saved', (
    tester,
  ) async {
    final saves = _GatedSaveService();
    final s = await buildFakeServices(tips: true, profileSaves: saves);
    saves.gated = true; // the save that marks the tip as shown is slow
    await pumpApp(tester, s);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    await tester.tap(find.byKey(TestIds.homePlay));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    saves.release();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byKey(TestIds.tipHome), findsNothing);
  });

  testWidgets('no tip in a game, in pause or on game over', (tester) async {
    final s = await buildFakeServices(tips: true);
    await s.profile.closeHomeTip();
    await openGame(tester, doomed(), services: s);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    expect(find.byKey(TestIds.tipHome), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
