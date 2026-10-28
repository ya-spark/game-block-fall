import 'package:flutter/material.dart';
import 'package:blockfall/app.dart';
import 'package:blockfall/core/services.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

Future<void> pumpApp(WidgetTester tester, Services s) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

void main() {
  testWidgets('home shows the main menu', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    for (final k in [
      TestIds.homePlay,
      TestIds.homeDailyReward,
      TestIds.homeChallenges,
      TestIds.homeShop,
      TestIds.homeSettings,
      TestIds.homeCoins,
      TestIds.homeBestScore,
    ]) {
      expect(find.byKey(k), findsOneWidget, reason: '$k');
    }
  });

  testWidgets('daily reward screen: claim adds coins and disables the button', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeDailyReward));
    await tester.pumpAndSettle();
    expect(find.byKey(TestIds.dailyDay(6)), findsOneWidget);
    await tester.tap(find.byKey(TestIds.dailyClaim));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 30);
    final btn = tester.widget<FilledButton>(find.byKey(TestIds.dailyClaim));
    expect(btn.onPressed, isNull);
  });

  testWidgets(
    'challenges screen lists three daily challenges and achievements',
    (tester) async {
      final s = await buildFakeServices();
      await pumpApp(tester, s);
      await tester.tap(find.byKey(TestIds.homeChallenges));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(TestIds.challengeTile(i)), findsOneWidget);
      }
      expect(
        find.byKey(TestIds.achievementTile('ach_first_row')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shop: buying remove ads marks it owned and disables ads', (
    tester,
  ) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeShop));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.shopBuy('remove_ads')));
    await tester.pumpAndSettle();
    expect(s.profile.data.adsRemoved, isTrue);
    expect(s.ads.adsEnabled, isFalse);
    expect(find.byKey(TestIds.shopBuy('remove_ads')), findsNothing);
    await tester.tap(find.byKey(TestIds.shopBuy('coins_500')));
    await tester.pumpAndSettle();
    expect(s.profile.data.coins, 500);
  });

  testWidgets('settings toggles persist to the profile', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homeSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TestIds.settingsSound));
    await tester.pumpAndSettle();
    expect(s.profile.data.soundOn, isFalse);
    expect(find.byKey(TestIds.settingsPlayGames), findsOneWidget);
  });

  testWidgets('game: screen opens from Play and goes back', (tester) async {
    final s = await buildFakeServices();
    await pumpApp(tester, s);
    await tester.tap(find.byKey(TestIds.homePlay));
    // The Flame loop never settles: pump fixed durations.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(TestIds.gameWidget), findsOneWidget);
    expect(find.byKey(TestIds.gameScore), findsOneWidget);
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    await tester.tap(find.byKey(TestIds.gameBack));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(TestIds.homePlay), findsOneWidget);
  });
}
