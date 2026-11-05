import 'dart:math';
import 'dart:ui';

import 'package:blockfall/core/save/save_data.dart';
import 'package:blockfall/game/rules/bag.dart';
import 'package:blockfall/game/rules/blockfall_game.dart';
import 'package:blockfall/game/rules/piece_type.dart';
import 'package:blockfall/game/rules/theme_rotation.dart';
import 'package:blockfall/game/rules/well.dart';
import 'package:blockfall/game/flame/blockfall_flame_game.dart';
import 'package:blockfall/game/themes/block_theme.dart';
import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_services.dart';
import '../helpers/game_harness.dart';

void main() {
  group('theme rotation', () {
    test('changes on every level-up in table order and wraps around', () {
      expect(
        [for (var l = 1; l <= 7; l++) ThemeRotation.idFor(0, l)],
        ['gems', 'cakes', 'wood', 'candy', 'ocean', 'space', 'gems'],
      );
      expect(ThemeRotation.idFor(5, 1), 'space');
      expect(ThemeRotation.idFor(5, 2), 'gems');
      expect(ThemeRotation.idFor(2, 6), 'cakes');
    });

    test('themes are in table order, 7 distinct colours each', () {
      expect([for (final t in BlockTheme.all) t.id], ThemeRotation.ids);
      for (final t in BlockTheme.all) {
        expect(t.palette.length, 7);
        expect(t.palette.toSet().length, 7, reason: t.id);
      }
    });

    test('a piece type has a different colour in every theme', () {
      for (final type in PieceType.values) {
        final colours = {
          for (final t in BlockTheme.all) t.colorOf(type.colorId),
        };
        expect(colours.length, BlockTheme.all.length, reason: type.name);
      }
    });

    test('the rotation index is saved and defaults to gems', () {
      final d = const SaveData().copyWith(themeIndex: 3);
      expect(SaveData.fromJson(d.toJson()).themeIndex, 3);
      expect(SaveData.fromJson(const {}).themeIndex, 0);
      expect(BlockTheme.byIndex(const SaveData().themeIndex).id, 'gems');
    });

    test('the flame game follows the level and continues from its start', () {
      final rules = BlockfallGame(
        random: Random(1),
        bag: PieceBag.sequence(const [PieceType.bar]),
        startLines: 10, // level 2
      );
      final flame = BlockfallFlameGame(rules: rules, themeStart: 4);
      expect(flame.theme.id, 'space'); // 4 + (2 - 1) = 5
      flame.reset(
        BlockfallGame(
          random: Random(1),
          bag: PieceBag.sequence(const [PieceType.bar]),
        ),
        themeStart: 5,
      );
      expect(flame.theme.id, 'space');
    });
  });

  group('skins', () {
    for (final t in BlockTheme.all) {
      test('${t.id} paints all 7 colours, with and without prism', () {
        final cache = ThemeTileCache();
        final rec = PictureRecorder();
        final canvas = Canvas(rec);
        for (var id = 1; id <= 7; id++) {
          for (final prism in [false, true]) {
            const rect = Rect.fromLTWH(0, 0, 40, 40);
            t.paintCell(canvas, rect, id, prism: prism, pulse: 0.3);
            cache.draw(canvas, t, id, rect, prism: prism, pulse: 0.3);
          }
          t.paintGhost(canvas, const Rect.fromLTWH(0, 0, 40, 40), id);
        }
        t.paintBackground(canvas, const Size(300, 600));
        rec.endRecording().dispose();
        cache.dispose();
      });
    }
  });

  testWidgets('game.theme changes on level-up and is saved', (tester) async {
    final handle = tester.ensureSemantics();
    final g = BlockfallGame(
      random: Random(1),
      bag: PieceBag.sequence(const [PieceType.bar]),
      well: Well.fromRows(List.filled(4, '111111111.')),
      prismInterval: 0,
      startLines: 8,
    );
    final s = await openGame(tester, g, buttons: true);
    expect(semValue(tester, TestIds.gameTheme), 'gems');
    await tapKey(tester, TestIds.gameCtlRotate);
    for (var i = 0; i < 4; i++) {
      await tapKey(tester, TestIds.gameCtlRight);
    }
    await tapKey(tester, TestIds.gameCtlHardDrop);
    expect(g.level, 2);
    await settle(tester, 2);
    expect(semValue(tester, TestIds.gameTheme), 'cakes');
    expect(s.profile.data.themeIndex, 1);
    // The cross-fade runs 1.5 s and never blocks anything.
    await settle(tester, 20);
    expect(semValue(tester, TestIds.gameTheme), 'cakes');
    handle.dispose();
  });

  group('hud text', () {
    double lum(Color c) {
      double ch(double v) =>
          v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color a, Color b) {
      final la = lum(a), lb = lum(b);
      return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
    }

    // Candy (pale background) must reach WCAG AA. The dark themes keep white and only
    // have a regression floor.
    test('candy hudText and hudSubtle reach 4.5 on the top colour', () {
      final t = BlockTheme.candy;
      expect(contrast(t.hudText, t.backgroundTop), greaterThanOrEqualTo(4.5));
      expect(contrast(t.hudSubtle, t.backgroundTop), greaterThanOrEqualTo(4.5));
    });

    for (final t in BlockTheme.all) {
      test('${t.id} hudText never gets harder to read than 2.0', () {
        expect(contrast(t.hudText, t.backgroundTop), greaterThanOrEqualTo(2.0));
      });
    }
  });

  testWidgets('candy: the SCORE label, score and best use the Candy colours', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await buildFakeServices();
    await s.profile.setThemeIndex(3);
    final g = BlockfallGame(random: Random(1));
    await openGame(tester, g, services: s);
    expect(semValue(tester, TestIds.gameTheme), 'candy');
    Color colorOf(Key k) => tester.widget<Text>(find.byKey(k)).style!.color!;
    expect(colorOf(TestIds.gameScoreLabel), BlockTheme.candy.hudSubtle);
    expect(colorOf(TestIds.gameBestText), BlockTheme.candy.hudText);
    final score = tester.widget<Text>(
      find.descendant(
        of: find.byKey(TestIds.gameScore),
        matching: find.text('0'),
      ),
    );
    expect(score.style!.color, BlockTheme.candy.hudText);
    handle.dispose();
  });
}
