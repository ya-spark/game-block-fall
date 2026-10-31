import 'package:flutter/material.dart';

import '../core/services.dart';
import 'challenges_screen.dart';
import 'daily_reward_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'test_ids.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ServicesScope.of(context).profile.onAppOpened();
    }
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final profile = s.profile;
    return Scaffold(
      // The only banner in the app: Home (never in play or on the game over dialog).
      bottomNavigationBar: s.config.adPacing.bannerEnabled
          ? SafeArea(
              child: KeyedSubtree(
                key: TestIds.homeBanner,
                child: s.ads.buildBanner(),
              ),
            )
          : null,
      body: KidBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: profile,
            builder: (context, _) {
              final claimable = profile.challenges.any((c) => c.claimable);
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      PopIn(
                        child: Text(
                          '\u{1F9E9} ${s.config.displayName} \u{2728}',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: KidColors.purpleDark,
                                blurRadius: 0,
                                offset: Offset(3, 4),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          KeyedSubtree(
                            key: TestIds.homeCoins,
                            child: StatChip(
                              icon: Icons.monetization_on,
                              label: '${profile.data.coins}',
                              color: KidColors.orange,
                            ),
                          ),
                          KeyedSubtree(
                            key: TestIds.homeBestScore,
                            child: StatChip(
                              icon: Icons.emoji_events,
                              color: KidColors.purple,
                              label: 'Best ${profile.data.bestScore}',
                            ),
                          ),
                          if (s.config.retention.streaks)
                            KeyedSubtree(
                              key: TestIds.homeStreak,
                              child: StatChip(
                                icon: Icons.local_fire_department,
                                label: '${profile.displayStreak}',
                                color: Colors.deepOrange,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MenuButton(
                        key: TestIds.homePlay,
                        label: 'Play',
                        icon: Icons.play_arrow,
                        emoji: '\u{25B6}\u{FE0F}',
                        primary: true,
                        top: KidColors.green,
                        bottom: KidColors.greenDark,
                        onPressed: () => _open(const GameScreen()),
                      ),
                      if (s.config.retention.dailyReward)
                        MenuButton(
                          key: TestIds.homeDailyReward,
                          label: 'Daily reward',
                          icon: Icons.card_giftcard,
                          emoji: '\u{1F381}',
                          top: KidColors.pink,
                          bottom: KidColors.pinkDark,
                          index: 1,
                          badge: profile.dailyRewardAvailable,
                          onPressed: () => _open(const DailyRewardScreen()),
                        ),
                      if (s.config.retention.dailyChallenges ||
                          s.config.retention.achievements)
                        MenuButton(
                          key: TestIds.homeChallenges,
                          label: 'Challenges',
                          icon: Icons.flag,
                          emoji: '\u{1F3C6}',
                          top: KidColors.sun,
                          bottom: KidColors.orange,
                          index: 2,
                          badge: claimable,
                          onPressed: () => _open(const ChallengesScreen()),
                        ),
                      MenuButton(
                        key: TestIds.homeShop,
                        label: 'Shop',
                        icon: Icons.shopping_cart,
                        emoji: '\u{1F6D2}',
                        top: KidColors.purple,
                        bottom: KidColors.purpleDark,
                        index: 3,
                        onPressed: () => _open(const ShopScreen()),
                      ),
                      MenuButton(
                        key: TestIds.homeSettings,
                        label: 'Settings',
                        icon: Icons.settings,
                        emoji: '\u{2699}\u{FE0F}',
                        index: 4,
                        onPressed: () => _open(const SettingsScreen()),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
