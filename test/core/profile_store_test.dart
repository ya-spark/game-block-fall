import 'package:blockfall/core/clock.dart';
import 'package:blockfall/core/config/app_config.dart';
import 'package:blockfall/core/config/products.dart';
import 'package:blockfall/core/profile/profile_store.dart';
import 'package:blockfall/core/purchase/purchase_service.dart';
import 'package:blockfall/core/retention/daily_challenges.dart';
import 'package:blockfall/core/retention/daily_reward.dart';
import 'package:blockfall/core/save/legacy_prefs_migration.dart';
import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/core/save/save_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = ProductCatalog([
  ProductDef(
    id: 'remove_ads',
    type: ProductType.nonConsumable,
    title: 'Remove Ads',
    description: '',
    grants: 'remove_ads',
  ),
  ProductDef(
    id: 'coins_500',
    type: ProductType.consumable,
    title: 'Coins',
    description: '',
    coins: 500,
  ),
]);

void main() {
  late DateTime now;
  late MemorySaveService saves;

  ProfileStore make({RetentionConfig retention = const RetentionConfig()}) =>
      ProfileStore(saves: saves, retention: retention, clock: () => now);

  setUp(() {
    now = DateTime(2026, 3, 1, 10);
    saves = MemorySaveService();
  });

  test('daily reward: claim once per day, then again next day', () async {
    final p = make();
    await p.init();
    expect(p.dailyRewardAvailable, isTrue);
    expect((await p.claimDailyReward())?.coins, 30);
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
    now = now.add(const Duration(days: 1));
    await p.onAppOpened();
    expect(p.dailyRewardAvailable, isTrue);
    expect((await p.claimDailyReward())?.coins, 40);
    expect(p.data.coins, 70);
  });

  test('setting the clock back does not allow a second claim', () async {
    final p = make();
    await p.init();
    await p.claimDailyReward();
    now = now.subtract(const Duration(days: 2));
    await p.onAppOpened();
    expect(p.clockTampered, isTrue);
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
  });

  test('clock guard survives an app restart (persisted last seen)', () async {
    var p = make();
    await p.init();
    await p.claimDailyReward();
    now = now.subtract(const Duration(days: 2));
    p = make();
    await p.init();
    expect(p.dailyRewardAvailable, isFalse);
  });

  test('streak grows over consecutive days', () async {
    final p = make();
    await p.init();
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(days: 1));
      await p.onAppOpened();
    }
    expect(p.displayStreak, 4);
  });

  test('finishing a game updates stats, best score and challenges', () async {
    final p = make();
    await p.init();
    final unlocked = await p.recordGameFinished(
      const GameSummary(
        score: 1500,
        linesCleared: 6,
        piecesPlaced: 20,
        maxCombo: 3,
        quads: 1,
        prismRows: 2,
        holdsUsed: 5,
        level: 2,
      ),
    );
    expect(p.data.bestScore, 1500);
    expect(p.data.stats.gamesPlayed, 1);
    expect(p.data.stats.quads, 1);
    expect(p.data.stats.prismRows, 2);
    expect(p.data.stats.holdsUsed, 5);
    expect(p.data.stats.maxLevel, 2);
    expect(unlocked.map((a) => a.id), ['ach_first_row']);
    expect(p.data.coins, greaterThan(0)); // achievement rewards
    expect(p.data.challenges.challenges, hasLength(3));
  });

  test('game summary feeds the matching challenge kinds', () async {
    const expected = {
      ChallengeKind.scorePoints: 700,
      ChallengeKind.clearLines: 9,
      ChallengeKind.clearQuads: 2,
      ChallengeKind.reachLevel: 5,
      ChallengeKind.clearPrismRows: 3,
      ChallengeKind.makeCombo: 4,
      ChallengeKind.useHold: 6,
      ChallengeKind.playGames: 1,
    };
    final kinds = expected.keys.toList();
    expect(kinds.toSet(), ChallengeKind.values.toSet());
    // Three challenges per day: feed all kinds through three seeded days.
    for (var i = 0; i < kinds.length; i += 3) {
      final batch = [for (var j = 0; j < 3; j++) kinds[(i + j) % kinds.length]];
      saves = MemorySaveService(
        SaveData(
          challenges: DailyChallengesState(
            day: dayIndexOf(now),
            challenges: [
              for (final (n, k) in batch.indexed)
                Challenge(
                  id: 'c$n',
                  kind: k,
                  description: '',
                  target: 1000,
                  reward: 1,
                ),
            ],
          ),
        ),
      );
      final p = make();
      await p.init();
      await p.recordGameFinished(
        const GameSummary(
          score: 700,
          linesCleared: 9,
          piecesPlaced: 30,
          maxCombo: 4,
          quads: 2,
          prismRows: 3,
          holdsUsed: 6,
          level: 5,
        ),
      );
      for (final c in p.challenges) {
        expect(c.progress, expected[c.kind], reason: '${c.kind}');
      }
    }
  });

  group('daily reward grants power-ups', () {
    test('7-day cycle pays coins and power-up stock per the spec', () async {
      final p = make();
      await p.init();
      final claims = <DailyRewardClaim>[];
      for (var d = 0; d < 7; d++) {
        claims.add((await p.claimDailyReward())!);
        now = now.add(const Duration(days: 1));
        await p.onAppOpened();
      }
      expect(claims.map((c) => c.coins), [30, 40, 50, 0, 70, 0, 150]);
      expect(claims.map((c) => c.powerUps), [
        {},
        {},
        {},
        {'slow': 1},
        {},
        {'bomb': 1},
        {'sweep': 1},
      ]);
      // 340 from the cycle plus the 150 Daily Devotee achievement (7-day streak).
      expect(p.data.coins, 340 + 150);
      // Fresh stock is 1 of each; the cycle adds Slow, Bomb and Sweep once.
      expect(p.data.powerUps, {'sweep': 2, 'slow': 2, 'bomb': 2});
    });

    test('the stock is persisted and a missed day restarts at day 1', () async {
      var p = make();
      await p.init();
      for (var d = 0; d < 4; d++) {
        await p.claimDailyReward();
        now = now.add(const Duration(days: 1));
        await p.onAppOpened();
      }
      expect(saves.data.powerUps['slow'], 2);
      now = now.add(const Duration(days: 3));
      p = make();
      await p.init();
      expect((await p.claimDailyReward())?.coins, 30);
    });
  });

  group('Blockfall settings and stock', () {
    test('defaults: 1 of each power-up, ghost on, default controls', () async {
      final p = make();
      await p.init();
      expect(p.data.powerUps, {'sweep': 1, 'slow': 1, 'bomb': 1});
      expect(p.data.ghostOn, isTrue);
      expect(p.controlScheme, ProfileStore.defaultControls);
    });

    test('setters persist', () async {
      final p = make();
      await p.init();
      await p.setControls(ControlScheme.buttons);
      await p.setGhost(false);
      await p.setPowerUps({'sweep': 0, 'slow': 3, 'bomb': -4});
      await p.addPowerUp('sweep', 2);
      expect(saves.data.controls, ControlScheme.buttons);
      expect(saves.data.ghostOn, isFalse);
      expect(saves.data.powerUps, {'sweep': 2, 'slow': 3, 'bomb': 0});
      final q = make();
      await q.init();
      expect(q.controlScheme, ControlScheme.buttons);
    });

    test('legacy SharedPreferences values move into the save', () async {
      SharedPreferences.setMockInitialValues({
        'bf.controls': 'buttons',
        'bf.ghost': false,
        'bf.stock.sweep': 0,
        'bf.stock.slow': 3,
        'other': 'kept',
      });
      final prefs = await SharedPreferences.getInstance();
      final p = make();
      await p.init();
      expect(await migrateLegacyBlockfallPrefs(prefs, p), isTrue);
      expect(p.controlScheme, ControlScheme.buttons);
      expect(p.data.ghostOn, isFalse);
      expect(p.data.powerUps, {'sweep': 0, 'slow': 3, 'bomb': 1});
      expect(prefs.getKeys(), {'other'});
      // Second run: nothing left to import.
      expect(await migrateLegacyBlockfallPrefs(prefs, p), isFalse);
      expect(p.data.powerUps['slow'], 3);
    });

    test('no legacy keys: the save is untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final p = make();
      await p.init();
      final before = saves.saves;
      expect(await migrateLegacyBlockfallPrefs(prefs, p), isFalse);
      expect(saves.saves, before);
    });
  });

  test('features can be switched off by config', () async {
    final p = make(
      retention: const RetentionConfig(
        dailyReward: false,
        streaks: false,
        dailyChallenges: false,
        achievements: false,
      ),
    );
    await p.init();
    expect(p.dailyRewardAvailable, isFalse);
    expect(await p.claimDailyReward(), isNull);
    expect(p.challenges, isEmpty);
    final unlocked = await p.recordGameFinished(
      const GameSummary(
        score: 5,
        linesCleared: 0,
        piecesPlaced: 1,
        maxCombo: 1,
      ),
    );
    expect(unlocked, isEmpty);
  });

  test('remove-ads purchase sets the flag; restore is idempotent', () async {
    final p = make();
    await p.init();
    const u = PurchaseUpdate('remove_ads', PurchaseStatus.purchased);
    await p.deliverPurchase(u, _catalog);
    await p.deliverPurchase(u, _catalog);
    expect(p.data.adsRemoved, isTrue);
  });

  test('consumable is granted once per purchase id', () async {
    final p = make();
    await p.init();
    const u = PurchaseUpdate(
      'coins_500',
      PurchaseStatus.purchased,
      purchaseId: 'order-1',
    );
    await p.deliverPurchase(u, _catalog);
    await p.deliverPurchase(u, _catalog); // replay
    expect(p.data.coins, 500);
    await p.deliverPurchase(
      const PurchaseUpdate(
        'coins_500',
        PurchaseStatus.purchased,
        purchaseId: 'order-2',
      ),
      _catalog,
    );
    expect(p.data.coins, 1000);
  });

  test('canceled purchases grant nothing', () async {
    final p = make();
    await p.init();
    await p.deliverPurchase(
      const PurchaseUpdate('remove_ads', PurchaseStatus.canceled),
      _catalog,
    );
    expect(p.data.adsRemoved, isFalse);
  });

  test('spendCoins refuses to go negative', () async {
    final p = make();
    await p.init();
    await p.addCoins(10);
    expect(await p.spendCoins(11), isFalse);
    expect(await p.spendCoins(10), isTrue);
    expect(p.data.coins, 0);
  });

  test('state is persisted after changes', () async {
    final p = make();
    await p.init();
    await p.addCoins(5);
    expect(saves.data.coins, 5);
  });
}
