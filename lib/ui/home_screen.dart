import 'package:flutter/material.dart';

import '../core/services.dart';
import '../game/themes/block_theme.dart';
import 'home_hero.dart';
import 'more_games_screen.dart';
import 'routes.dart';
import 'test_ids.dart';
import 'theme_fade.dart';
import 'tip_card.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTip());
  }

  /// True only when Home is the page on top and no run is on screen.
  bool _homeIsOnTop(Services s) =>
      mounted && !s.inRun && ModalRoute.of(context)?.isCurrent == true;

  bool _tipBusy = false;

  /// The tip of the day: one dialog the first time Home is shown each day (never in play).
  /// Never queued: when the guard blocks it nothing happens, and the next Home visit tries again.
  Future<void> _maybeShowTip() async {
    if (_tipBusy || !mounted) return;
    final s = ServicesScope.of(context);
    final profile = s.profile;
    if (!_homeIsOnTop(s) || !profile.homeTipPending) return;
    _tipBusy = true;
    try {
      final text = s.tips.tipOfTheDay(profile.today);
      // Counts as shown for today as soon as it opens.
      await profile.closeHomeTip();
      // The save is async: a run may have started meanwhile, so check again before opening.
      if (!mounted || !_homeIsOnTop(s)) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: TipCard(
            key: TestIds.tipHome,
            title: 'Tip of the day',
            text: text,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } finally {
      _tipBusy = false;
    }
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

  void _open(String route) => Navigator.of(context).pushNamed(route);

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
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, child) => ThemeBackground(
          theme: BlockTheme.byIndex(profile.data.themeIndex),
          child: child!,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: ListenableBuilder(
                listenable: profile,
                builder: (context, _) {
                  final claimable = profile.challenges.any((c) => c.claimable);
                  return LayoutBuilder(
                    builder: (context, box) {
                      final offer = !profile.data.adsRemoved;
                      final (heroH, gap) = homeLayout(
                        box.maxHeight,
                        removeAdsOffer: offer,
                      );
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: gap,
                            children: [
                              HomeHero(height: heroH),
                              PopIn(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '\u{1F9E9} ${s.config.displayName} \u{2728}',
                                    maxLines: 1,
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
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  KeyedSubtree(
                                    key: TestIds.homeCoins,
                                    child: StatChip(
                                      iconWidget: const CoinIcon(),
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
                              if (offer)
                                RemoveAdsPill(
                                  key: TestIds.homeRemoveAds,
                                  onPressed: () => _open(AppRoutes.shop),
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
                                onPressed: () => _open(AppRoutes.play),
                              ),
                              HomeGrid(
                                children: [
                                  if (s.config.retention.dailyReward)
                                    MenuButton(
                                      compact: true,
                                      key: TestIds.homeDailyReward,
                                      label: 'Daily reward',
                                      icon: Icons.card_giftcard,
                                      emoji: '\u{1F381}',
                                      top: KidColors.teal,
                                      bottom: KidColors.tealDark,
                                      index: 1,
                                      badge: profile.dailyRewardAvailable,
                                      onPressed: () =>
                                          _open(AppRoutes.dailyReward),
                                    ),
                                  if (s.config.retention.dailyChallenges ||
                                      s.config.retention.achievements)
                                    MenuButton(
                                      compact: true,
                                      key: TestIds.homeChallenges,
                                      label: 'Challenges',
                                      icon: Icons.flag,
                                      emoji: '\u{1F3C6}',
                                      top: KidColors.sun,
                                      bottom: KidColors.orange,
                                      index: 2,
                                      badge: claimable,
                                      onPressed: () =>
                                          _open(AppRoutes.challenges),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      if (s.config.visibleMoreGames.isNotEmpty)
                        HomeIconButton(
                          key: TestIds.homeMoreGames,
                          icon: Icons.apps,
                          label: 'More games',
                          colors: const [KidColors.teal, KidColors.tealDark],
                          onPressed: () => openMoreGames(context),
                        ),
                      HomeIconButton(
                        key: TestIds.homeShop,
                        icon: Icons.shopping_basket,
                        label: 'Shop',
                        colors: const [KidColors.purple, KidColors.purpleDark],
                        onPressed: () => _open(AppRoutes.shop),
                      ),
                      HomeIconButton(
                        key: TestIds.homeSettings,
                        icon: Icons.settings,
                        label: 'Settings',
                        colors: const [KidColors.blue, KidColors.blueDark],
                        onPressed: () => _open(AppRoutes.settings),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
