import 'dart:typed_data';

import 'package:game_blockfall/blockfall.dart';

import 'ads/ad_service.dart';
import 'analytics/analytics_service.dart';
import 'leaderboard/leaderboard_service.dart';
import 'services.dart';
import 'share/share_service.dart';

/// What the Blockfall game asks of this app, backed by this app's own services (shop, coins, Remove
/// Ads, ads, share, leaderboard, analytics). Provided above the game by `BlockfallServicesScope`.
class BlockfallServicesAdapter implements BlockfallServices {
  BlockfallServicesAdapter(this._s);
  final Services _s;

  @override
  BlockfallConfig get config => _Config(_s);
  @override
  BlockfallProfileStore get profile => _s.profile;
  @override
  BlockfallAds get ads => _Ads(_s.ads);
  @override
  BlockfallLeaderboard get leaderboard => _Leaderboard(_s.leaderboard);
  @override
  BlockfallAnalytics get analytics => _Analytics(_s.analytics);
  @override
  BlockfallShare get share => _Share(_s.share);

  @override
  bool get inRun => _s.inRun;
  @override
  set inRun(bool v) => _s.inRun = v;
}

class _Config implements BlockfallConfig {
  _Config(this._s);
  final Services _s;
  @override
  String get displayName => _s.config.displayName;
  @override
  String get leaderboardHighScore => _s.config.playGames.leaderboardHighScore;
  @override
  bool get streaksEnabled => _s.config.retention.streaks;
}

class _Ads implements BlockfallAds {
  _Ads(this._a);
  final AdService _a;
  @override
  Future<bool> showRewarded(BlockfallAdPlacement placement) =>
      _a.showRewarded(AdPlacement.values.byName(placement.name));
  @override
  Future<void> maybeShowInterstitialAfterGameOver() async {
    await _a.maybeShowInterstitialAfterGameOver();
  }
}

class _Leaderboard implements BlockfallLeaderboard {
  _Leaderboard(this._l);
  final LeaderboardService _l;
  @override
  Future<void> submitScore(String leaderboardId, int score) =>
      _l.submitScore(leaderboardId, score);
  @override
  Future<void> unlockAchievement(String achievementId) =>
      _l.unlockAchievement(achievementId);
}

class _Analytics implements BlockfallAnalytics {
  _Analytics(this._a);
  final AnalyticsService _a;
  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      _a.logEvent(name, params);
}

class _Share implements BlockfallShare {
  _Share(this._s);
  final ShareService _s;
  @override
  Future<void> shareScore({required int score, Uint8List? image}) =>
      _s.shareScore(score: score, image: image);
}
