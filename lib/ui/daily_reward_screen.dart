import 'package:flutter/material.dart';

import '../core/retention/daily_reward.dart';
import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  static double _cardWidth(BuildContext context) =>
      ((MediaQuery.sizeOf(context).width - 32 - 24) / 4).clamp(60.0, 110.0);

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u{1F381} Daily reward'),
        backgroundColor: KidColors.blueDark,
        foregroundColor: Colors.white,
      ),
      body: KidBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final today = profile.dailyRewardDayToClaim;
              final available = profile.dailyRewardAvailable;
              // Days before `today` in the cycle are done if the reward was claimed on that streak.
              final claimedThrough = available
                  ? today
                  : (today == 0 ? DailyRewardEngine.cycleLength : today);
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (s.config.retention.streaks)
                            StatChip(
                              key: TestIds.dailyStreak,
                              icon: Icons.local_fire_department,
                              color: Colors.deepOrange,
                              label:
                                  'Streak: ${profile.displayStreak} days  \u2022  Freezes: ${profile.data.streak.freezes}',
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (
                                var i = 0;
                                i < DailyRewardEngine.cycleLength;
                                i++
                              )
                                SizedBox(
                                  width: _cardWidth(context),
                                  height: _cardWidth(context) / 0.8,
                                  child: _DayCard(
                                    key: TestIds.dailyDay(i),
                                    day: i + 1,
                                    coin:
                                        DailyRewardEngine.rewards[i].coins > 0,
                                    label: DailyRewardEngine.rewards[i].label,
                                    done: i < claimedThrough,
                                    today: i == today && available,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Kept inside the safe area so the Android nav buttons never cover it.
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: FilledButton(
                          key: TestIds.dailyClaim,
                          style: FilledButton.styleFrom(
                            backgroundColor: KidColors.green,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                          onPressed: available
                              ? () async {
                                  final c = await profile.claimDailyReward();
                                  if (c != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Reward: ${DailyRewardEngine.rewards[c.day].label}',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            available ? 'Claim' : 'Come back tomorrow',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.day,
    required this.coin,
    required this.label,
    required this.done,
    required this.today,
  });
  final int day;

  /// Coin reward (shows the [CoinIcon]) or a power-up reward (bolt).
  final bool coin;
  final String label;
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final top = done
        ? KidColors.green
        : (today ? KidColors.sun : KidColors.blue);
    return Container(
      decoration: BoxDecoration(
        color: done ? const Color(0xFFD9F9E6) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: top, width: today ? 4 : 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: top,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Day $day',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: today ? KidColors.ink : Colors.white,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  coin
                      ? const CoinIcon(size: 28)
                      : const Icon(Icons.bolt, color: KidColors.sun, size: 28),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: KidColors.ink,
                    ),
                  ),
                  if (done)
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: KidColors.green,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
