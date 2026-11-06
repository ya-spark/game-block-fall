import 'dart:math';

import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/purchase/parent_gate.dart';
import 'package:blockfall/core/purchase/purchase_service.dart';
import 'package:blockfall/app.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/powerups.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/game_harness.dart';
import '../helpers/gate_helpers.dart';

BlockfallGame doomed() => mk(rows: List.filled(22, '111111111.'));

Future<void> own(Services s) => s.profile.deliverPurchase(
  const PurchaseUpdate('remove_ads_all', PurchaseStatus.purchased),
  s.catalog,
);

void main() {
  group('ParentGate logic', () {
    test('questions use factors 6 to 9 and change', () {
      final g = ParentGate(random: Random(5));
      GateQuestion? prev;
      for (var i = 0; i < 50; i++) {
        final q = g.newQuestion(prev);
        expect(q.a, inInclusiveRange(6, 9));
        expect(q.b, inInclusiveRange(6, 9));
        expect(q.text, '${q.a} x ${q.b}');
        if (prev != null) expect([q.a, q.b], isNot([prev.a, prev.b]));
        prev = q;
      }
    });

    test('3 wrong in a row lock for 60 s, then unlock (fake clock)', () {
      var now = DateTime(2026, 1, 1, 12);
      final g = ParentGate(clock: () => now);
      const q = GateQuestion(7, 8);
      expect(g.submit(q, '1'), GateResult.wrong);
      expect(g.submit(q, '2'), GateResult.wrong);
      expect(g.submit(q, '3'), GateResult.locked);
      expect(g.isLocked, isTrue);
      expect(g.submit(q, '56'), GateResult.locked, reason: 'even if right');
      now = now.add(const Duration(seconds: 59));
      expect(g.isLocked, isTrue);
      now = now.add(const Duration(seconds: 1));
      expect(g.isLocked, isFalse);
      expect(g.submit(q, '56'), GateResult.correct);
    });

    test('a correct answer resets the wrong counter', () {
      final g = ParentGate();
      const q = GateQuestion(6, 9);
      expect(g.submit(q, '1'), GateResult.wrong);
      expect(g.submit(q, '2'), GateResult.wrong);
      expect(g.submit(q, '54'), GateResult.correct);
      expect(g.submit(q, '1'), GateResult.wrong);
      expect(g.submit(q, '2'), GateResult.wrong);
    });
  });

  group('parent gate in the shop', () {
    Future<Services> openShop(WidgetTester tester, {ParentGate? gate}) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await buildFakeServices(parentGate: gate);
      await tester.pumpWidget(GameApp(services: s));
      await tester.pump();
      await tester.tap(find.byKey(TestIds.homeShop));
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('cancel buys nothing; a wrong answer shows a new question', (
      tester,
    ) async {
      final s = await openShop(tester);
      await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await answerGateWrong(tester);
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      expect(s.profile.data.coins, 0);
      await tester.tap(find.byKey(TestIds.gateCancel));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsNothing);
      expect(s.profile.data.coins, 0);
    });

    testWidgets('correct answer buys; 3 wrong close and lock for 60 s', (
      tester,
    ) async {
      var now = DateTime(2026, 1, 1, 12);
      final s = await openShop(tester, gate: ParentGate(clock: () => now));
      await tester.tap(find.byKey(TestIds.shopBuy('coins_1500')));
      await tester.pumpAndSettle();
      await answerGate(tester);
      expect(s.profile.data.coins, 1500);

      await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await answerGateWrong(tester);
      }
      expect(find.byKey(TestIds.gateDialog), findsNothing);
      await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsNothing, reason: 'locked');
      expect(s.profile.data.coins, 1500);

      now = now.add(const Duration(seconds: 60));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsOneWidget);
      await answerGate(tester);
      expect(s.profile.data.coins, 2000);
    });

    testWidgets('Restore needs no gate', (tester) async {
      await openShop(tester);
      await tester.tap(find.byKey(TestIds.shopRestore));
      await tester.pumpAndSettle();
      expect(find.byKey(TestIds.gateDialog), findsNothing);
    });
  });

  group('Continue needs a rewarded ad', () {
    testWidgets('with 1000 coins it calls the ad directly, spends no coins', (
      tester,
    ) async {
      final ads = FakeAdService();
      final g = doomed();
      final s = await buildFakeServices(ads: ads);
      await s.profile.addCoins(1000);
      await openGame(tester, g, services: s);
      await tapKey(tester, TestIds.gameOverRevive);
      expect(find.byType(AlertDialog), findsNothing);
      expect(ads.rewardedShown, 1);
      expect(g.isGameOver, isFalse);
      expect(g.revivesUsed, 1);
      expect(s.profile.data.coins, 1000);
    });

    testWidgets('ad not earned: no continue, panel open, coins unchanged', (
      tester,
    ) async {
      final ads = FakeAdService(rewardResult: false);
      final g = doomed();
      final s = await buildFakeServices(ads: ads);
      await s.profile.addCoins(1000);
      await openGame(tester, g, services: s);
      await tapKey(tester, TestIds.gameOverRevive);
      expect(ads.rewardedShown, 1);
      expect(g.isGameOver, isTrue);
      expect(g.revivesUsed, 0);
      expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
      expect(find.textContaining('No ad available right now'), findsOneWidget);
      expect(s.profile.data.coins, 1000);
    });

    testWidgets('an ad continue counts against the per-run limit', (
      tester,
    ) async {
      final g = doomed();
      final s = await buildFakeServices();
      await openGame(tester, g, services: s);
      expect(g.revivesRemaining, PowerUpRules.maxRevivesPerRun);
      await tapKey(tester, TestIds.gameOverRevive);
      expect(g.revivesRemaining, PowerUpRules.maxRevivesPerRun - 1);
    });

    testWidgets('Remove Ads owners continue at once, no ad, no coins', (
      tester,
    ) async {
      final ads = FakeAdService();
      final g = doomed();
      final s = await buildFakeServices(ads: ads);
      await s.profile.addCoins(500);
      await own(s);
      await openGame(tester, g, services: s);
      await tapKey(tester, TestIds.gameOverRevive);
      expect(ads.rewardedShown, 0);
      expect(s.profile.data.coins, 500);
      expect(g.isGameOver, isFalse);
    });

    testWidgets('Remove Ads refills a power-up free, max 3 per game', (
      tester,
    ) async {
      final ads = FakeAdService();
      final g = mk(stock: {PowerUpType.bomb: 0});
      final s = await buildFakeServices(ads: ads);
      await own(s);
      await openGame(tester, g, services: s);
      await tapKey(tester, TestIds.gamePowerUpBomb);
      expect(find.text('Get +1 free (3 left)'), findsOneWidget);
      await tapKey(tester, TestIds.gameRefillAd);
      expect(g.stock(PowerUpType.bomb), 1);
      expect(g.adRefillsUsed, 1);
      expect(ads.rewardedShown, 0);
    });
  });
}
