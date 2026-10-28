import 'package:flutter/foundation.dart';

import '../clock.dart';
import '../config/app_config.dart';
import '../config/products.dart';
import '../purchase/purchase_service.dart';
import '../retention/achievements.dart';
import '../retention/daily_challenges.dart';
import '../retention/daily_reward.dart';
import '../retention/streaks.dart';
import '../save/save_data.dart';
import '../save/save_service.dart';

/// Result of one finished game, fed into stats / challenges / achievements.
class GameSummary {
  const GameSummary({
    required this.score,
    required this.linesCleared,
    required this.piecesPlaced,
    required this.maxCombo,
    this.quads = 0,
    this.prismRows = 0,
    this.holdsUsed = 0,
    this.perfectClears = 0,
    this.level = 1,
  });
  final int score;
  final int linesCleared;
  final int piecesPlaced;
  final int maxCombo;

  /// Quads (4 rows at once) cleared this game.
  final int quads;

  /// Rows holding a prism that were cleared this game.
  final int prismRows;
  final int holdsUsed;
  final int perfectClears;

  /// Level reached when the game ended.
  final int level;
}

/// Holds the player's [SaveData], applies the retention engines and persists every change.
/// UI listens to it; game rules never touch it.
class ProfileStore extends ChangeNotifier {
  /// `--dart-define=BLOCKFALL_CONTROLS=buttons` makes Buttons the default (bot / tests).
  static const ControlScheme defaultControls =
      String.fromEnvironment('BLOCKFALL_CONTROLS') == 'buttons'
      ? ControlScheme.buttons
      : ControlScheme.touch;

  ProfileStore({required this._saves, required this.retention, Clock? clock})
    : _clock = clock ?? DateTime.now;

  final SaveService _saves;
  final RetentionConfig retention;
  final Clock _clock;
  static const ClockGuard _guard = ClockGuard();

  SaveData _data = const SaveData();
  SaveData get data => _data;

  /// Device clock is behind the latest time we saw (the player moved it back).
  bool clockTampered = false;

  /// Time used for all date logic: never earlier than the latest time ever seen.
  DateTime get trustedNow => _guard.trusted(_clock(), _data.lastSeenMs);
  int get today => dayIndexOf(trustedNow);

  Future<void> init() async {
    _data = await _saves.load();
    await _tick();
  }

  /// Call on app start and on resume: refreshes the day, streak and today's challenges.
  Future<void> onAppOpened() => _tick();

  Future<void> _tick() async {
    final raw = _clock();
    clockTampered = _guard.isTampered(raw, _data.lastSeenMs);
    final now = _guard.trusted(raw, _data.lastSeenMs);
    final day = dayIndexOf(now);
    var d = _data.copyWith(lastSeenMs: now.millisecondsSinceEpoch);
    if (retention.streaks) {
      final u = StreakEngine.recordActivity(d.streak, day);
      d = d.copyWith(
        streak: u.state,
        stats: d.stats.copyWith(
          bestStreak: u.state.best > d.stats.bestStreak ? u.state.best : null,
        ),
      );
    }
    if (retention.dailyChallenges) {
      d = d.copyWith(
        challenges: DailyChallengeEngine.ensureToday(d.challenges, day),
      );
    }
    d = _unlockAchievements(d).data;
    await _commit(d);
  }

  Future<void> _commit(SaveData d) async {
    _data = d;
    notifyListeners();
    await _saves.save(d);
  }

  // ---- daily reward -------------------------------------------------------

  bool get dailyRewardAvailable =>
      retention.dailyReward &&
      DailyRewardEngine.canClaim(_data.dailyReward, today);

  int get dailyRewardDayToClaim =>
      DailyRewardEngine.dayToClaim(_data.dailyReward, today);

  /// Claims today's reward (coins and/or power-ups); null if unavailable.
  Future<DailyRewardClaim?> claimDailyReward() async {
    if (!retention.dailyReward) return null;
    final c = DailyRewardEngine.claim(_data.dailyReward, today);
    if (c == null) return null;
    await _commit(
      _data.copyWith(
        dailyReward: c.state,
        coins: _data.coins + c.coins,
        powerUps: _withPowerUps(_data.powerUps, c.powerUps),
      ),
    );
    return c;
  }

  static Map<String, int> _withPowerUps(
    Map<String, int> stock,
    Map<String, int> add,
  ) => {
    for (final id in kPowerUpIds)
      id: (stock[id] ?? 0) + (add[id] ?? 0) < 0
          ? 0
          : (stock[id] ?? 0) + (add[id] ?? 0),
  };

  // ---- streak -------------------------------------------------------------

  int get displayStreak => StreakEngine.displayStreak(_data.streak, today);

  // ---- challenges ---------------------------------------------------------

  List<Challenge> get challenges =>
      retention.dailyChallenges ? _data.challenges.challenges : const [];

  Future<int?> claimChallenge(String id) async {
    final r = DailyChallengeEngine.claim(_data.challenges, id);
    if (r == null) return null;
    await _commit(
      _data.copyWith(challenges: r.state, coins: _data.coins + r.coins),
    );
    return r.coins;
  }

  // ---- gameplay -----------------------------------------------------------

  /// Records a finished game. Returns achievements unlocked by it.
  Future<List<AchievementDef>> recordGameFinished(GameSummary g) async {
    var d = _data;
    final stats = d.stats.copyWith(
      gamesPlayed: d.stats.gamesPlayed + 1,
      totalLines: d.stats.totalLines + g.linesCleared,
      piecesPlaced: d.stats.piecesPlaced + g.piecesPlaced,
      bestScore: g.score > d.stats.bestScore ? g.score : null,
      maxCombo: g.maxCombo > d.stats.maxCombo ? g.maxCombo : null,
      quads: d.stats.quads + g.quads,
      prismRows: d.stats.prismRows + g.prismRows,
      holdsUsed: d.stats.holdsUsed + g.holdsUsed,
      perfectClears: d.stats.perfectClears + g.perfectClears,
      maxLevel: g.level > d.stats.maxLevel ? g.level : null,
    );
    d = d.copyWith(
      stats: stats,
      bestScore: g.score > d.bestScore ? g.score : null,
    );
    if (retention.dailyChallenges) {
      var c = DailyChallengeEngine.ensureToday(d.challenges, today);
      c = DailyChallengeEngine.record(c, ChallengeKind.playGames, 1);
      c = DailyChallengeEngine.record(c, ChallengeKind.scorePoints, g.score);
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.clearLines,
        g.linesCleared,
      );
      c = DailyChallengeEngine.record(c, ChallengeKind.clearQuads, g.quads);
      c = DailyChallengeEngine.record(c, ChallengeKind.reachLevel, g.level);
      c = DailyChallengeEngine.record(
        c,
        ChallengeKind.clearPrismRows,
        g.prismRows,
      );
      c = DailyChallengeEngine.record(c, ChallengeKind.makeCombo, g.maxCombo);
      c = DailyChallengeEngine.record(c, ChallengeKind.useHold, g.holdsUsed);
      d = d.copyWith(challenges: c);
    }
    final r = _unlockAchievements(d);
    await _commit(r.data);
    return r.unlocked;
  }

  ({SaveData data, List<AchievementDef> unlocked}) _unlockAchievements(
    SaveData d,
  ) {
    if (!retention.achievements) return (data: d, unlocked: const []);
    final fresh = AchievementEngine.newlyUnlocked(
      d.stats,
      d.unlockedAchievements,
    );
    if (fresh.isEmpty) return (data: d, unlocked: const []);
    return (
      data: d.copyWith(
        unlockedAchievements: {
          ...d.unlockedAchievements,
          for (final a in fresh) a.id,
        },
        coins: d.coins + fresh.fold<int>(0, (s, a) => s + a.reward),
      ),
      unlocked: fresh,
    );
  }

  // ---- coins / settings ---------------------------------------------------

  Future<void> addCoins(int n) =>
      _commit(_data.copyWith(coins: _data.coins + n));

  Future<bool> spendCoins(int n) async {
    if (_data.coins < n) return false;
    await _commit(_data.copyWith(coins: _data.coins - n));
    return true;
  }

  Future<void> setSound(bool v) => _commit(_data.copyWith(soundOn: v));
  Future<void> setVibration(bool v) => _commit(_data.copyWith(vibrationOn: v));
  Future<void> setReminders(bool v) => _commit(_data.copyWith(remindersOn: v));

  // ---- Blockfall settings and power-up stock ------------------------------

  /// The scheme in use: the saved choice, else [defaultControls] (a build-time default).
  ControlScheme get controlScheme => _data.controls ?? defaultControls;
  Future<void> setControls(ControlScheme v) =>
      _commit(_data.copyWith(controls: v));
  Future<void> setGhost(bool v) => _commit(_data.copyWith(ghostOn: v));

  int powerUpCount(String id) => _data.powerUpCount(id);

  /// Replaces the stock (the game writes its remaining stock back during play).
  Future<void> setPowerUps(Map<String, int> stock) async {
    final next = _withPowerUps({for (final id in kPowerUpIds) id: 0}, stock);
    if (mapEquals(next, _data.powerUps)) return;
    await _commit(_data.copyWith(powerUps: next));
  }

  Future<void> addPowerUp(String id, [int n = 1]) =>
      _commit(_data.copyWith(powerUps: _withPowerUps(_data.powerUps, {id: n})));

  /// One-off import of the settings the game kept in SharedPreferences before they moved
  /// into [SaveData]. Values already chosen in the save win over the imported ones.
  Future<void> importLegacySettings({
    Map<String, int>? powerUps,
    ControlScheme? controls,
    bool? ghost,
  }) => _commit(
    _data.copyWith(
      powerUps: powerUps == null
          ? null
          : _withPowerUps({for (final id in kPowerUpIds) id: 0}, powerUps),
      controls: _data.controls ?? controls,
      ghostOn: ghost,
    ),
  );

  // ---- purchases ----------------------------------------------------------

  /// Delivers a purchase/restore once. Replays of the same purchaseId are ignored;
  /// restores of non-consumables are idempotent by nature.
  Future<void> deliverPurchase(PurchaseUpdate u, ProductCatalog catalog) async {
    if (u.status != PurchaseStatus.purchased &&
        u.status != PurchaseStatus.restored) {
      return;
    }
    final def = catalog.byId(u.productId);
    if (def == null) return;
    var d = _data;
    if (def.type == ProductType.consumable) {
      final key = u.purchaseId;
      if (u.status == PurchaseStatus.restored) {
        return; // consumables are never restored
      }
      if (key != null && d.processedPurchases.contains(key)) {
        return;
      }
      d = d.copyWith(
        coins: d.coins + def.coins,
        processedPurchases: key == null ? null : {...d.processedPurchases, key},
      );
    } else if (def.grants == ProductDef.removeAdsGrant) {
      d = d.copyWith(adsRemoved: true);
    }
    await _commit(d);
  }
}
