import 'package:flutter/material.dart';

import '../core/retention/achievements.dart';
import '../core/services.dart';
import 'test_ids.dart';
import 'widgets.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u{1F3C6} Challenges'),
        backgroundColor: KidColors.orange,
        foregroundColor: Colors.white,
      ),
      body: KidBackground(
        child: SafeArea(
        child: ListenableBuilder(
        listenable: profile,
        builder: (context, _) {
          final stats = profile.data.stats;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (s.config.retention.dailyChallenges) ...[
                const _Heading('\u{1F4C5} Daily challenges'),
                for (final (i, c) in profile.challenges.indexed)
                  Card(
                    key: TestIds.challengeTile(i),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ListTile(
                      minVerticalPadding: 14,
                      title: Text(c.description),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            color: KidColors.green,
                            backgroundColor: const Color(0xFFE5E7EB),
                            value: (c.progress / c.target)
                                .clamp(0, 1)
                                .toDouble(),
                          ),
                        ),
                      ),
                      trailing: c.claimed
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton(
                              key: TestIds.challengeClaim(c.id),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(72, 52),
                                backgroundColor: KidColors.sun,
                                foregroundColor: KidColors.ink,
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              onPressed: c.claimable
                                  ? () => profile.claimChallenge(c.id)
                                  : null,
                              child: Text('+${c.reward} \u{1FA99}'),
                            ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              if (s.config.retention.achievements) ...[
                const _Heading('\u{1F31F} Achievements'),
                for (final a in AchievementEngine.all)
                  Card(
                    color: const Color(0xD9FFFFFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: ListTile(
                    key: TestIds.achievementTile(a.id),
                    leading: Icon(
                      profile.data.unlockedAchievements.contains(a.id)
                          ? Icons.emoji_events
                          : Icons.lock_outline,
                      color: profile.data.unlockedAchievements.contains(a.id)
                          ? Colors.amber
                          : null,
                    ),
                    title: Text(a.title),
                    subtitle: Text(
                      '${a.description}  (${a.valueIn(stats).clamp(0, a.target)}/${a.target})',
                    ),
                    trailing: Text('+${a.reward} \u{1FA99}'),
                    ),
                  ),
              ],
            ],
          );
        },
        ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [
          Shadow(color: KidColors.purpleDark, offset: Offset(2, 3)),
        ],
      ),
    ),
  );
}
