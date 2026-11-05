import 'package:blockfall/game/themes/block_theme.dart';
import 'package:blockfall/ui/game_over_panel.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:blockfall/ui/theme_fade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduce = false, VoidCallback? onRetry}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: GameOverPanel(
      panelKey: TestIds.gameOverPanel,
      viewKey: TestIds.gameOverView,
      title: 'Game over',
      details: const [Text('Score 120')],
      buttons: [
        GameOverButton(
          key: TestIds.gameOverRetry,
          label: 'Play again',
          onPressed: onRetry ?? () {},
        ),
      ],
    ),
  ),
);

class _Probe extends StatelessWidget {
  const _Probe();
  @override
  Widget build(BuildContext context) => Text(
    '1',
    key: const Key('probe'),
    style: TextStyle(shadows: HudColors.of(context).shadows),
  );
}

void main() {
  testWidgets('eases in: hold 0.3 s, then fade; tappable after 1 s', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_app(onRetry: () => taps++));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(TestIds.gameOverPanel), findsNothing, reason: 'hold');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(TestIds.gameOverPanel), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(TestIds.gameOverRetry), warnIfMissed: false);
    expect(taps, 0, reason: 'not tappable before 1 s');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    expect(taps, 1);
    expect(find.text('Score 120'), findsOneWidget);
  });

  testWidgets('reduce motion shortens it to 0.2 s', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(reduce: true, onRetry: () => taps++));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(TestIds.gameOverPanel), findsOneWidget);
    await tester.tap(find.byKey(TestIds.gameOverRetry), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byKey(TestIds.gameOverRetry));
    expect(taps, 1);
  });

  testWidgets('HUD text carries the shadow on Gems and Ocean only', (
    tester,
  ) async {
    Future<List<Shadow>?> shadowsFor(BlockTheme theme) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeBackground(theme: theme, child: const _Probe()),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      return tester.widget<Text>(find.byKey(const Key('probe'))).style?.shadows;
    }

    for (final t in [BlockTheme.gems, BlockTheme.ocean]) {
      final s = await shadowsFor(t);
      expect(s, isNotEmpty, reason: t.id);
      expect(s!.first.blurRadius, 2);
      expect(s.first.color.a, closeTo(0.4, 0.01));
    }
    expect(await shadowsFor(BlockTheme.wood), isEmpty);
  });
}
