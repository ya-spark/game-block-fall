import 'package:flutter/material.dart';

import '../core/retention/daily_reward.dart';
import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

class DailyRewardScreen extends StatelessWidget {
  const DailyRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u{1F381} Daily reward'),
        backgroundColor: KidColors.pink,
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
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 2000,
                            crossAxisCount: 4,
                            childAspectRatio: 0.8,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: [
                              for (
                                var i = 0;
                                i < DailyRewardEngine.cycleLength;
                                i++
                              )
                                Card(
                                  key: TestIds.dailyDay(i),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  color: i < claimedThrough
                                      ? const Color(0xFFBBF7D0)
                                      : (i == today && available
                                            ? KidColors.sun
                                            : Colors.white),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Day ${i + 1}'),
                                      Icon(
                                        DailyRewardEngine.rewards[i].coins > 0
                                            ? Icons.monetization_on
                                            : Icons.bolt,
                                        color: KidColors.orange,
                                      ),
                                      Text(DailyRewardEngine.rewards[i].label),
                                      if (i < claimedThrough)
                                        const Icon(Icons.check, size: 16),
                                    ],
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
