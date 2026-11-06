import 'package:blockfall/app.dart';
import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';

/// Fake ads with a 50 dp banner so Home reserves the real banner height.
class _BannerAds extends FakeAdService {
  @override
  Widget buildBanner() => const SizedBox(height: 50, width: double.infinity);
}

Future<void> _pumpHome(
  WidgetTester tester,
  Size size, {
  bool banner = true,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final s = await buildFakeServices(ads: banner ? _BannerAds() : null);
  await tester.pumpWidget(GameApp(services: s));
  await tester.pump();
}

void _expectFits(WidgetTester tester, Size size) {
  expect(tester.takeException(), isNull);
  final view = Offset.zero & size;
  for (final k in [
    TestIds.homePlay,
    TestIds.homeDailyReward,
    TestIds.homeChallenges,
    TestIds.homeShop,
    TestIds.homeSettings,
  ]) {
    final r = tester.getRect(find.byKey(k));
    expect(
      view.contains(r.topLeft) && view.contains(r.bottomRight),
      isTrue,
      reason: '$k $r is outside $view',
    );
  }
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  expect(scroll.position.maxScrollExtent, 0);
}

void main() {
  for (final size in const [Size(360, 640), Size(360, 592), Size(400, 800)]) {
    testWidgets('home fits without scrolling at $size', (tester) async {
      await _pumpHome(tester, size);
      _expectFits(tester, size);
    });
  }

  testWidgets('home fits at 360 x 640 without a banner', (tester) async {
    await _pumpHome(tester, const Size(360, 640), banner: false);
    _expectFits(tester, const Size(360, 640));
  });

  testWidgets('home has no overflow at text scale 1.5', (tester) async {
    await _pumpHome(tester, const Size(360, 640), textScale: 1.5);
    expect(tester.takeException(), isNull);
  });
}
