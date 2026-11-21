import 'package:flutter_test/flutter_test.dart';
import 'package:game_blockfall/blockfall.dart';
import 'package:game_blockfall/testing.dart' as game_testing;

import 'package:blockfall/core/ads/ad_service.dart';
import 'package:blockfall/core/blockfall_host.dart';
import 'package:blockfall/core/services.dart';

import 'fake_services.dart';

/// Opens the game screen under this app's own services (through the adapter the app gives the
/// game). The game's bots and helpers come from `package:game_blockfall/testing.dart`.
Future<Services> openGame(
  WidgetTester tester,
  BlockfallGame game, {
  bool buttons = false,
  AdService? ads,
  Services? services,
}) async {
  final s = services ?? await buildFakeServices(ads: ads);
  if (buttons) {
    await s.profile.setControls(ControlScheme.buttons);
  }
  await game_testing.pumpGame(tester, game, BlockfallServicesAdapter(s));
  return s;
}
