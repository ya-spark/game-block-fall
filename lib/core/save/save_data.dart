import '../retention/achievements.dart';
import '../retention/daily_challenges.dart';
import '../retention/daily_reward.dart';
import '../retention/streaks.dart';

/// How the falling piece is steered (Settings > controls).
enum ControlScheme { touch, buttons }

/// Power-up ids used in [SaveData.powerUps] (equal to `PowerUpType.name` in the game rules;
/// a test keeps them in sync). `lib/core` must not import the game.
const List<String> kPowerUpIds = ['sweep', 'slow', 'bomb'];

/// Stock a fresh install starts with (1 of each).
const Map<String, int> kInitialPowerUps = {'sweep': 1, 'slow': 1, 'bomb': 1};

/// Everything persisted for the player. Plain JSON, versioned.
class SaveData {
  const SaveData({
    this.coins = 0,
    this.bestScore = 0,
    this.adsRemoved = false,
    this.soundOn = true,
    this.vibrationOn = true,
    this.remindersOn = false,
    this.lastSeenMs = 0,
    this.savedAtMs = 0,
    this.dailyReward = const DailyRewardState(),
    this.streak = const StreakState(),
    this.challenges = const DailyChallengesState(),
    this.stats = const LifetimeStats(),
    this.unlockedAchievements = const {},
    this.processedPurchases = const {},
    this.powerUps = kInitialPowerUps,
    this.controls,
    this.ghostOn = true,
  });

  /// Bump when the JSON shape changes and add a step to [SaveMigrator].
  static const int currentVersion = 3;

  final int coins;
  final int bestScore;
  final bool adsRemoved;
  final bool soundOn;
  final bool vibrationOn;
  final bool remindersOn;

  /// Latest time ever seen (UTC ms), for the backwards-clock guard.
  final int lastSeenMs;

  /// When this save was written (UTC ms); used to pick a winner when merging with cloud saves.
  final int savedAtMs;
  final DailyRewardState dailyReward;
  final StreakState streak;
  final DailyChallengesState challenges;
  final LifetimeStats stats;
  final Set<String> unlockedAchievements;

  /// Purchase IDs already delivered, so a replayed purchase is not granted twice.
  final Set<String> processedPurchases;

  /// Power-up stock by id (see [kPowerUpIds]); never negative.
  final Map<String, int> powerUps;

  /// Chosen control scheme, or null while the player has not picked one (the app default
  /// applies, which `--dart-define=BLOCKFALL_CONTROLS=buttons` can set for the bot).
  final ControlScheme? controls;

  /// Show the landing ghost.
  final bool ghostOn;

  int powerUpCount(String id) => powerUps[id] ?? 0;

  SaveData copyWith({
    int? coins,
    int? bestScore,
    bool? adsRemoved,
    bool? soundOn,
    bool? vibrationOn,
    bool? remindersOn,
    int? lastSeenMs,
    int? savedAtMs,
    DailyRewardState? dailyReward,
    StreakState? streak,
    DailyChallengesState? challenges,
    LifetimeStats? stats,
    Set<String>? unlockedAchievements,
    Set<String>? processedPurchases,
    Map<String, int>? powerUps,
    ControlScheme? controls,
    bool? ghostOn,
  }) => SaveData(
    coins: coins ?? this.coins,
    bestScore: bestScore ?? this.bestScore,
    adsRemoved: adsRemoved ?? this.adsRemoved,
    soundOn: soundOn ?? this.soundOn,
    vibrationOn: vibrationOn ?? this.vibrationOn,
    remindersOn: remindersOn ?? this.remindersOn,
    lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    savedAtMs: savedAtMs ?? this.savedAtMs,
    dailyReward: dailyReward ?? this.dailyReward,
    streak: streak ?? this.streak,
    challenges: challenges ?? this.challenges,
    stats: stats ?? this.stats,
    unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    processedPurchases: processedPurchases ?? this.processedPurchases,
    powerUps: powerUps ?? this.powerUps,
    controls: controls ?? this.controls,
    ghostOn: ghostOn ?? this.ghostOn,
  );

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'coins': coins,
    'bestScore': bestScore,
    'adsRemoved': adsRemoved,
    'soundOn': soundOn,
    'vibrationOn': vibrationOn,
    'remindersOn': remindersOn,
    'lastSeenMs': lastSeenMs,
    'savedAtMs': savedAtMs,
    'dailyReward': dailyReward.toJson(),
    'streak': streak.toJson(),
    'challenges': challenges.toJson(),
    'stats': stats.toJson(),
    'unlockedAchievements': unlockedAchievements.toList()..sort(),
    'processedPurchases': processedPurchases.toList()..sort(),
    'powerUps': powerUps,
    'controls': controls?.name,
    'ghostOn': ghostOn,
  };

  /// Expects JSON already migrated to [currentVersion].
  factory SaveData.fromJson(Map<String, Object?> j) => SaveData(
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
    adsRemoved: j['adsRemoved'] as bool? ?? false,
    soundOn: j['soundOn'] as bool? ?? true,
    vibrationOn: j['vibrationOn'] as bool? ?? true,
    remindersOn: j['remindersOn'] as bool? ?? false,
    lastSeenMs: (j['lastSeenMs'] as num?)?.toInt() ?? 0,
    savedAtMs: (j['savedAtMs'] as num?)?.toInt() ?? 0,
    dailyReward: DailyRewardState.fromJson(_map(j['dailyReward'])),
    streak: StreakState.fromJson(_map(j['streak'])),
    challenges: DailyChallengesState.fromJson(_map(j['challenges'])),
    stats: LifetimeStats.fromJson(_map(j['stats'])),
    unlockedAchievements: {
      ...?(j['unlockedAchievements'] as List?)?.cast<String>(),
    },
    processedPurchases: {
      ...?(j['processedPurchases'] as List?)?.cast<String>(),
    },
    powerUps: _powerUps(j['powerUps']),
    controls: ControlScheme.values.asNameMap()[j['controls']],
    ghostOn: j['ghostOn'] as bool? ?? true,
  );

  static Map<String, int> _powerUps(Object? o) {
    final m = _map(o);
    return {
      for (final id in kPowerUpIds)
        id:
            ((m?[id] is num ? (m![id]! as num).toInt() : null) ??
                    kInitialPowerUps[id]!)
                .clamp(0, 1 << 30),
    };
  }

  static Map<String, Object?>? _map(Object? o) =>
      o is Map ? o.cast<String, Object?>() : null;
}

/// Upgrades old save JSON step by step to [SaveData.currentVersion].
abstract final class SaveMigrator {
  static Map<String, Object?> migrate(Map<String, Object?> json) {
    var v = (json['version'] as num?)?.toInt() ?? 0;
    if (v > SaveData.currentVersion) {
      throw FormatException(
        'Save version $v is newer than supported ${SaveData.currentVersion}',
      );
    }
    var j = Map<String, Object?>.of(json);
    while (v < SaveData.currentVersion) {
      j = switch (v) {
        0 => _v0ToV1(j),
        1 => _v1ToV2(j),
        2 => _v2ToV3(j),
        _ => throw StateError('No migration from $v'),
      };
      v = (j['version'] as num).toInt();
    }
    return j;
  }

  /// v0 (pre-release prototype) stored `highScore` and `coinBalance`.
  static Map<String, Object?> _v0ToV1(Map<String, Object?> j) => {
    ...j,
    'version': 1,
    'bestScore': j['bestScore'] ?? j['highScore'] ?? 0,
    'coins': j['coins'] ?? j['coinBalance'] ?? 0,
  };

  /// v2 added `processedPurchases` and `savedAtMs`.
  static Map<String, Object?> _v1ToV2(Map<String, Object?> j) => {
    ...j,
    'version': 2,
    'processedPurchases': j['processedPurchases'] ?? const <String>[],
    'savedAtMs': j['savedAtMs'] ?? 0,
  };

  /// v3 (Blockfall) added the power-up stock, the controls scheme and the ghost toggle,
  /// and replaced the block-puzzle achievement set: unlocked ids that no longer exist are
  /// dropped (their lifetime stats stay).
  static Map<String, Object?> _v2ToV3(Map<String, Object?> j) => {
    ...j,
    'version': 3,
    'powerUps': j['powerUps'] ?? kInitialPowerUps,
    'ghostOn': j['ghostOn'] ?? true,
    'unlockedAchievements': [
      for (final id in (j['unlockedAchievements'] as List? ?? const []))
        if (id is String && id.startsWith('ach_')) id,
    ],
  };
}
