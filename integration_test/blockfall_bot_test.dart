// Emulator / device bot: runs the REAL app (real services, test ads in debug) and plays it
// through test IDs only. Run it on a device or emulator:
//
//   flutter test integration_test/blockfall_bot_test.dart \
//     --dart-define=BLOCKFALL_SEED=7 --dart-define=BLOCKFALL_CONTROLS=buttons
//
// CI runs it only in the manual emulator job (hosted runners cannot boot an emulator). The
// very same script (test/helpers/blockfall_scenario.dart) runs as a normal VM widget test in
// test/ui/e2e_bot_test.dart, which CI does run on every push.
import 'package:blockfall/main.dart' as app;
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/blockfall_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bot plays Blockfall from Home to game over and back', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await app.main();
    // Home has no endless animation, but plugin start-up (ads, billing) is still running.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byKey(TestIds.homePlay).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(TestIds.homePlay), findsOneWidget);

    await BlockfallScenario.fullAppRun(tester);

    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
