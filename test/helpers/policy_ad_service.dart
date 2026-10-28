import 'package:blockfall/core/ads/ad_frequency.dart';
import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/config/app_config.dart';
import 'package:flutter/widgets.dart';

/// An [AdService] that applies the real [AdFrequencyPolicy] with a controllable clock and
/// records every ad it "shows", so tests can check when ads appear.
class PolicyAdService implements AdService {
  PolicyAdService(AdPacingConfig pacing, this.clock)
    : policy = AdFrequencyPolicy(pacing, clock: clock);

  final DateTime Function() clock;
  final AdFrequencyPolicy policy;

  /// False simulates "ads fail to load": rewarded returns false, interstitials never show.
  bool loads = true;

  final List<DateTime> interstitialTimes = [];
  final List<AdPlacement> rewarded = [];
  int interstitialRequests = 0;
  bool _removed = false;

  @override
  Future<void> initialize() async {}
  @override
  bool get adsEnabled => !_removed;
  @override
  set adsRemoved(bool value) => _removed = value;
  @override
  bool get isRewardedReady => loads;

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    if (!loads) return false;
    rewarded.add(placement);
    policy.recordRewardedShown();
    return true;
  }

  @override
  Future<bool> maybeShowInterstitialAfterGameOver() async {
    interstitialRequests++;
    if (_removed || !loads) return false;
    if (!policy.shouldShowAfterGameOver()) return false;
    policy.recordShown();
    interstitialTimes.add(clock());
    return true;
  }

  @override
  Widget buildBanner() => const SizedBox.shrink();
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> showPrivacyOptions() async {}
}
