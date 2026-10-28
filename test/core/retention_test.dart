import 'package:blockfall/core/clock.dart';
import 'package:blockfall/core/retention/achievements.dart';
import 'package:blockfall/core/retention/daily_challenges.dart';
import 'package:blockfall/core/retention/daily_reward.dart';
import 'package:blockfall/core/retention/streaks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRewardEngine (7-day cycle)', () {
    test('first claim is day 1', () {
      const s = DailyRewardState();
      final c = DailyRewardEngine.claim(s, 100)!;
      expect(c.day, 0);
      expect(c.coins, 30);
    });

    test('cannot claim twice on the same day', () {
      final c = DailyRewardEngine.claim(const DailyRewardState(), 100)!;
      expect(DailyRewardEngine.canClaim(c.state, 100), isFalse);
      expect(DailyRewardEngine.claim(c.state, 100), isNull);
    });

    test('consecutive days walk the cycle and wrap after day 7', () {
      var s = const DailyRewardState();
      final days = <int>[];
      for (var d = 100; d < 109; d++) {
        final c = DailyRewardEngine.claim(s, d)!;
        days.add(c.day);
        s = c.state;
      }
      expect(days, [0, 1, 2, 3, 4, 5, 6, 0, 1]);
    });

    test('missing a day restarts the cycle', () {
      var s = DailyRewardEngine.claim(const DailyRewardState(), 100)!.state;
      s = DailyRewardEngine.claim(s, 101)!.state;
      final c = DailyRewardEngine.claim(s, 103)!; // skipped 102
      expect(c.day, 0);
    });

    test('the cycle pays the spec rewards', () {
      final r = DailyRewardEngine.rewards;
      expect(r.map((e) => e.coins), [30, 40, 50, 0, 70, 0, 150]);
      expect(r[3].powerUps, {'slow': 1});
      expect(r[5].powerUps, {'bomb': 1});
      expect(r[6].powerUps, {'sweep': 1});
      expect(r[6].label, '150 + Sweep');
      expect(r[3].label, 'Slow');
    });

    test('json round trip', () {
      const s = DailyRewardState(nextDay: 3, lastClaimDay: 42);
      final r = DailyRewardState.fromJson(s.toJson());
      expect(r.nextDay, 3);
      expect(r.lastClaimDay, 42);
    });
  });

  group('StreakEngine', () {
    test('increments on consecutive days, same day is a no-op', () {
      var s = const StreakState();
      s = StreakEngine.recordActivity(s, 10).state;
      expect(s.current, 1);
      expect(StreakEngine.recordActivity(s, 10).changed, isFalse);
      s = StreakEngine.recordActivity(s, 11).state;
      s = StreakEngine.recordActivity(s, 12).state;
      expect(s.current, 3);
      expect(s.best, 3);
    });

    test('a missed day resets the streak without a freeze', () {
      var s = const StreakState(current: 5, best: 5, lastActiveDay: 10);
      final u = StreakEngine.recordActivity(s, 12);
      expect(u.state.current, 1);
      expect(u.state.best, 5);
      expect(u.broken, isTrue);
    });

    test('a freeze covers one missed day', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      final u = StreakEngine.recordActivity(s, 12);
      expect(u.state.current, 6);
      expect(u.state.freezes, 0);
      expect(u.freezesUsed, 1);
    });

    test('freezes are optional: disabled means the streak breaks', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      final u = StreakEngine.recordActivity(s, 12, useFreezes: false);
      expect(u.state.current, 1);
      expect(u.state.freezes, 1);
    });

    test('not enough freezes for a long gap breaks the streak', () {
      const s = StreakState(current: 5, best: 5, lastActiveDay: 10, freezes: 1);
      expect(StreakEngine.recordActivity(s, 14).state.current, 1);
    });

    test('a freeze is earned every 7 days, capped', () {
      var s = const StreakState();
      for (var d = 0; d < 7; d++) {
        s = StreakEngine.recordActivity(s, d).state;
      }
      expect(s.current, 7);
      expect(s.freezes, 1);
      for (var d = 7; d < 30; d++) {
        s = StreakEngine.recordActivity(s, d).state;
      }
      expect(s.freezes, StreakEngine.maxFreezes);
    });

    test('displayStreak reads 0 once the streak lapsed', () {
      const s = StreakState(current: 4, best: 4, lastActiveDay: 10);
      expect(StreakEngine.displayStreak(s, 11), 4);
      expect(StreakEngine.displayStreak(s, 13), 0);
    });
  });

  group('DailyChallengeEngine', () {
    test(
      'creates exactly three distinct challenges, deterministic per day',
      () {
        final a = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          200,
        );
        final b = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          200,
        );
        expect(a.challenges, hasLength(3));
        expect(a.challenges.map((c) => c.kind).toSet(), hasLength(3));
        expect(
          a.challenges.map((c) => c.id).toList(),
          b.challenges.map((c) => c.id).toList(),
        );
      },
    );

    test('keeps progress within a day, regenerates on a new day', () {
      var s = DailyChallengeEngine.ensureToday(const DailyChallengesState(), 5);
      final kind = s.challenges.first.kind;
      s = DailyChallengeEngine.record(s, kind, 1);
      expect(DailyChallengeEngine.ensureToday(s, 5), same(s));
      final next = DailyChallengeEngine.ensureToday(s, 6);
      expect(next.day, 6);
      expect(next.challenges.every((c) => c.progress == 0), isTrue);
    });

    test('progress completes and can be claimed exactly once', () {
      var s = DailyChallengeEngine.ensureToday(const DailyChallengesState(), 9);
      final c = s.challenges.first;
      s = DailyChallengeEngine.record(s, c.kind, c.target);
      final r = DailyChallengeEngine.claim(s, c.id)!;
      expect(r.coins, c.reward);
      expect(DailyChallengeEngine.claim(r.state, c.id), isNull);
    });

    test('cannot claim an incomplete challenge', () {
      final s = DailyChallengeEngine.ensureToday(
        const DailyChallengesState(),
        9,
      );
      expect(DailyChallengeEngine.claim(s, s.challenges.first.id), isNull);
    });

    test('max-type challenges keep the best value, others accumulate', () {
      var s = DailyChallengesState(
        day: 1,
        challenges: const [
          Challenge(
            id: 'a',
            kind: ChallengeKind.scorePoints,
            description: '',
            target: 500,
            reward: 1,
          ),
          Challenge(
            id: 'b',
            kind: ChallengeKind.clearLines,
            description: '',
            target: 10,
            reward: 1,
          ),
        ],
      );
      s = DailyChallengeEngine.record(s, ChallengeKind.scorePoints, 200);
      s = DailyChallengeEngine.record(s, ChallengeKind.scorePoints, 150);
      s = DailyChallengeEngine.record(s, ChallengeKind.clearLines, 3);
      s = DailyChallengeEngine.record(s, ChallengeKind.clearLines, 4);
      expect(s.challenges[0].progress, 200);
      expect(s.challenges[1].progress, 7);
    });

    test('eight templates with rewards of 25 to 60 coins', () {
      expect(DailyChallengeEngine.templates, hasLength(8));
      expect(
        DailyChallengeEngine.templates.map((t) => t.kind).toSet(),
        ChallengeKind.values.toSet(),
      );
      for (final t in DailyChallengeEngine.templates) {
        expect(t.targets.length, t.rewards.length);
        expect(t.targets.length, inInclusiveRange(2, 3));
        expect(t.rewards, everyElement(inInclusiveRange(25, 60)));
      }
    });

    test('every day for a year yields valid targets and rewards', () {
      for (var day = 0; day < 365; day++) {
        final s = DailyChallengeEngine.ensureToday(
          const DailyChallengesState(),
          day,
        );
        expect(s.challenges, hasLength(3));
        for (final c in s.challenges) {
          expect(c.target, greaterThan(0));
          expect(c.reward, inInclusiveRange(25, 60));
          expect(c.description, isNot(contains('{n}')));
        }
      }
    });

    test('challenges of a retired kind in an old save are dropped', () {
      final s = DailyChallengesState.fromJson({
        'day': 5,
        'challenges': [
          {
            'id': 'x',
            'kind': 'placePieces',
            'description': 'Place 30 pieces',
            'target': 30,
            'reward': 20,
          },
        ],
      });
      expect(s.challenges, isEmpty);
      expect(DailyChallengeEngine.ensureToday(s, 5).challenges, hasLength(3));
    });

    test('json round trip', () {
      final s = DailyChallengeEngine.ensureToday(
        const DailyChallengesState(),
        77,
      );
      final r = DailyChallengesState.fromJson(s.toJson());
      expect(r.day, 77);
      expect(r.challenges.length, 3);
      expect(r.challenges.first.description, s.challenges.first.description);
    });
  });

  group('AchievementEngine', () {
    List<String> ids(LifetimeStats s) =>
        AchievementEngine.newlyUnlocked(s, {}).map((a) => a.id).toList();

    test('there are exactly the ten spec achievements', () {
      expect(AchievementEngine.all.map((a) => a.id), [
        'ach_first_row',
        'ach_century',
        'ach_quad_squad',
        'ach_prism_collector',
        'ach_combo_master',
        'ach_speed_demon',
        'ach_perfect',
        'ach_hold_tactician',
        'ach_marathoner',
        'ach_daily_devotee',
      ]);
    });

    test('nothing unlocked for zero stats', () {
      expect(ids(const LifetimeStats()), isEmpty);
    });

    test('each achievement unlocks on its condition, not before', () {
      final cases = <String, (LifetimeStats, LifetimeStats)>{
        'ach_first_row': (
          const LifetimeStats(totalLines: 0),
          const LifetimeStats(totalLines: 1),
        ),
        'ach_century': (
          const LifetimeStats(totalLines: 99),
          const LifetimeStats(totalLines: 100),
        ),
        'ach_quad_squad': (
          const LifetimeStats(quads: 3),
          const LifetimeStats(quads: 4),
        ),
        'ach_prism_collector': (
          const LifetimeStats(prismRows: 49),
          const LifetimeStats(prismRows: 50),
        ),
        'ach_combo_master': (
          const LifetimeStats(maxCombo: 4),
          const LifetimeStats(maxCombo: 5),
        ),
        'ach_speed_demon': (
          const LifetimeStats(maxLevel: 9),
          const LifetimeStats(maxLevel: 10),
        ),
        'ach_perfect': (
          const LifetimeStats(),
          const LifetimeStats(perfectClears: 1),
        ),
        'ach_hold_tactician': (
          const LifetimeStats(holdsUsed: 99),
          const LifetimeStats(holdsUsed: 100),
        ),
        'ach_marathoner': (
          const LifetimeStats(bestScore: 19999),
          const LifetimeStats(bestScore: 20000),
        ),
        'ach_daily_devotee': (
          const LifetimeStats(bestStreak: 6),
          const LifetimeStats(bestStreak: 7),
        ),
      };
      expect(
        cases.keys.toSet(),
        AchievementEngine.all.map((a) => a.id).toSet(),
      );
      for (final e in cases.entries) {
        expect(ids(e.value.$1), isNot(contains(e.key)), reason: e.key);
        expect(ids(e.value.$2), contains(e.key), reason: e.key);
      }
    });

    test('unlocks once', () {
      const stats = LifetimeStats(totalLines: 5);
      final first = AchievementEngine.newlyUnlocked(stats, {});
      final again = AchievementEngine.newlyUnlocked(
        stats,
        first.map((a) => a.id).toSet(),
      );
      expect(again, isEmpty);
    });

    test('achievement ids are unique', () {
      final ids = AchievementEngine.all.map((a) => a.id);
      expect(ids.toSet().length, ids.length);
    });

    test('stats json round trip keeps the new counters', () {
      const s = LifetimeStats(
        quads: 2,
        prismRows: 3,
        holdsUsed: 4,
        perfectClears: 5,
        maxLevel: 6,
      );
      final r = LifetimeStats.fromJson(s.toJson());
      expect(
        [r.quads, r.prismRows, r.holdsUsed, r.perfectClears, r.maxLevel],
        [2, 3, 4, 5, 6],
      );
    });
  });

  group('dayIndexOf', () {
    test('uses the local calendar date', () {
      expect(
        dayIndexOf(DateTime(2026, 1, 2, 23, 59)) -
            dayIndexOf(DateTime(2026, 1, 1, 0, 1)),
        1,
      );
    });
  });
}
