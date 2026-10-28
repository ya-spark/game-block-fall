import 'dart:math';

import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/config/app_config.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/powerups.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/blockfall_bot.dart';
import '../helpers/fake_services.dart';
import '../helpers/game_harness.dart';
import '../helpers/policy_ad_service.dart';

/// Drops pieces straight down until the well tops out (no line can complete that way).
Future<int> dropUntilGameOver(BlockfallBot bot, {int max = 80}) async {
  var n = 0;
  while (!bot.isGameOver && n < max) {
    await bot.hardDrop();
    n++;
  }
  expect(bot.isGameOver, isTrue, reason: 'game over within $max drops');
  return n;
}

void main() {
  late DateTime now;
  late AdPacingConfig pacing;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    pacing = const AdPacingConfig();
  });

  test(
    'the test pacing equals the pacing shipped in app.config.yaml',
    () async {
      final s = await buildFakeServices();
      const p = AdPacingConfig();
      expect(s.config.adPacing.interstitialMinIntervalSeconds, 90);
      expect(s.config.adPacing.interstitialEveryNGameOvers, 2);
      expect(s.config.adPacing.maxInterstitialsPerSession, 6);
      expect(s.config.adPacing.noInterstitialFirstSeconds, 60);
      expect(p.interstitialMinIntervalSeconds, 90);
      expect(p.maxInterstitialsPerSession, 6);
    },
  );

  testWidgets('no ad during play; interstitial caps hold after game over', (
    tester,
  ) async {
    final ads = PolicyAdService(pacing, () => now);
    await openGame(
      tester,
      BlockfallGame(random: Random(2)),
      buttons: true,
      ads: ads,
    );
    final bot = BlockfallBot(tester);

    // Mid-game: pieces fall, power-ups and Hold are used, still no ad of any kind.
    await bot.hardDrop();
    await bot.hold();
    await bot.hardDrop();
    await tapKey(tester, TestIds.gamePowerUpSlow);
    expect(find.byKey(TestIds.gameBanner), findsNothing);
    expect(ads.interstitialRequests, 0);
    expect(ads.interstitialTimes, isEmpty);
    expect(ads.rewarded, isEmpty);

    const games = 14;
    for (var game = 1; game <= games; game++) {
      await dropUntilGameOver(bot);
      // The dialog is up, but nothing was requested until the player leaves it.
      expect(ads.interstitialRequests, game - 1);
      now = now.add(const Duration(seconds: 100));
      await tapKey(tester, TestIds.gameOverRetry);
      expect(ads.interstitialRequests, game);
    }

    final shown = ads.interstitialTimes;
    expect(
      shown.length,
      pacing.maxInterstitialsPerSession,
      reason: 'session cap',
    );
    expect(
      shown.first.difference(DateTime(2026, 1, 1, 12)).inSeconds,
      greaterThanOrEqualTo(pacing.noInterstitialFirstSeconds),
    );
    for (var i = 1; i < shown.length; i++) {
      expect(
        shown[i].difference(shown[i - 1]).inSeconds,
        greaterThanOrEqualTo(pacing.interstitialMinIntervalSeconds),
      );
    }
    // Every 2nd game over at most: 14 game overs allow 7, the cap leaves 6.
    expect(ads.policy.shownThisSession, 6);
  });

  testWidgets('game over twice within the first minute shows no interstitial', (
    tester,
  ) async {
    final ads = PolicyAdService(pacing, () => now);
    await openGame(
      tester,
      BlockfallGame(random: Random(3)),
      buttons: true,
      ads: ads,
    );
    final bot = BlockfallBot(tester);
    for (var i = 0; i < 2; i++) {
      await dropUntilGameOver(bot);
      now = now.add(const Duration(seconds: 10));
      await tapKey(tester, TestIds.gameOverRetry);
    }
    expect(ads.interstitialRequests, 2);
    expect(ads.interstitialTimes, isEmpty);
  });

  testWidgets('remove_ads: no interstitial, rewarded revive still works', (
    tester,
  ) async {
    final ads = PolicyAdService(pacing, () => now)..adsRemoved = true;
    now = now.add(const Duration(minutes: 10));
    final g = mk(rows: List.filled(22, '111111111.'));
    await openGame(tester, g, ads: ads);
    await tapKey(tester, TestIds.gameOverRevive);
    expect(ads.rewarded, [AdPlacement.revive]);
    expect(g.isGameOver, isFalse);
    for (var i = 0; i < 4; i++) {
      await ads.maybeShowInterstitialAfterGameOver();
    }
    expect(ads.interstitialTimes, isEmpty);
    expect(ads.isRewardedReady, isTrue);
  });

  testWidgets('ads fail to load and the player is not signed in: game works', (
    tester,
  ) async {
    final ads = PolicyAdService(pacing, () => now)..loads = false;
    final s = await buildFakeServices(ads: ads);
    expect(s.identity.isStub, isTrue, reason: 'not signed in to Play Games');
    await s.profile.setPowerUps({'sweep': 0, 'slow': 0, 'bomb': 0});
    final g = mk(stock: {for (final t in PowerUpType.values) t: 0});
    await openGame(tester, g, services: s, buttons: true);
    final bot = BlockfallBot(tester);

    // Playing, moving and holding need no ad and no account.
    await bot.rotate();
    await bot.right(2);
    await bot.hold();
    await bot.hardDrop();
    expect(g.piecesPlaced, greaterThan(0));

    // Out of stock: the ad refill fails quietly, the game keeps running.
    await tapKey(tester, TestIds.gamePowerUpSweep);
    await tapKey(tester, TestIds.gameRefillAd);
    expect(g.stock(PowerUpType.sweep), 0);
    expect(g.isGameOver, isFalse);
    expect(g.isPaused, isFalse);

    // Game over: a failed revive ad keeps the dialog, retry and home still work.
    await dropUntilGameOver(bot);
    await tapKey(tester, TestIds.gameOverRevive);
    expect(find.byKey(TestIds.gameOverDialog), findsOneWidget);
    await tapKey(tester, TestIds.gameOverRetry);
    expect(find.byKey(TestIds.gameOverDialog), findsNothing);
    expect(s.profile.data.stats.gamesPlayed, 1);
    expect(ads.rewarded, isEmpty);
    expect(ads.interstitialTimes, isEmpty);
    await bot.hardDrop();
    expect(tester.takeException(), isNull);
  });

  testWidgets('power-up refill uses its own ad placement', (tester) async {
    final ads = PolicyAdService(pacing, () => now);
    final g = mk(stock: {PowerUpType.bomb: 0});
    await openGame(tester, g, ads: ads);
    await tapKey(tester, TestIds.gamePowerUpBomb);
    await tapKey(tester, TestIds.gameRefillAd);
    expect(ads.rewarded, [AdPlacement.powerUp]);
    expect(g.stock(PowerUpType.bomb), 1);
  });
}
