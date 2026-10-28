import 'package:blockfall/app.dart';
import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/game/rules/powerups.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
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

void main() {
  testWidgets('shop lists remove_ads and coins_500 from the fake store', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.shopBuy('remove_ads')), findsOneWidget);
    expect(find.byKey(TestIds.shopBuy('coins_500')), findsOneWidget);
    expect(find.text('Remove Ads'), findsOneWidget);
    expect(find.text('Coin Pack'), findsOneWidget);
    expect(find.byKey(TestIds.shopUnavailable), findsNothing);
  });

  test('power-up ids in lib/core match the rules enum', () {
    expect([for (final t in PowerUpType.values) t.name], kPowerUpIds);
  });

  test('power-up coin prices in the rules are Sweep 60, Slow 40, Bomb 50', () {
    expect(PowerUpType.sweep.price, 60);
    expect(PowerUpType.slow.price, 40);
    expect(PowerUpType.bomb.price, 50);
  });

  for (final (type, key, price) in [
    (PowerUpType.sweep, TestIds.gamePowerUpSweep, 60),
    (PowerUpType.slow, TestIds.gamePowerUpSlow, 40),
    (PowerUpType.bomb, TestIds.gamePowerUpBomb, 50),
  ]) {
    testWidgets('refill sheet for ${type.name} shows and charges $price', (
      tester,
    ) async {
      final g = mk(stock: {type: 0});
      final s = await openGame(tester, g);
      await s.profile.addCoins(100);
      await tapKey(tester, key);
      expect(find.text('Buy with coins ($price)'), findsOneWidget);
      await tapKey(tester, TestIds.gameRefillCoins);
      expect(s.profile.data.coins, 100 - price);
      expect(g.stock(type), 1);
    });
  }
}
