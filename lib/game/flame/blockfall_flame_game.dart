import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart'
    show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;

import '../rules/active_piece.dart';
import '../rules/blockfall_game.dart';
import '../rules/events.dart';
import '../rules/piece_type.dart';
import '../rules/powerups.dart';
import '../rules/well.dart';
import 'blockfall_layout.dart';
import 'gem_painter.dart';
import 'touch_controls.dart';

/// Flame renderer for Blockfall. It owns the driving loop for a pure-Dart [BlockfallGame]:
/// calls `tick(dt)` each frame, drains the events, and paints the well. All rules stay in
/// [BlockfallGame]; input arrives through the public control methods (also used by the
/// on-screen buttons).
class BlockfallFlameGame extends FlameGame {
  BlockfallFlameGame({required this.rules, this.showGhost = true});

  /// The running rules engine. Replace through [reset].
  BlockfallGame rules;
  bool showGhost;

  /// Called for every rules event (haptics, game over, stats).
  void Function(GameEvent event)? onEvent;

  /// Bumped whenever something the HUD shows changed.
  final ValueNotifier<int> revision = ValueNotifier(0);

  late final TouchControls touch = TouchControls(
    cellWidth: 20,
    sink: ControlSink(
      moveLeft: moveLeft,
      moveRight: moveRight,
      rotate: rotate,
      softDrop: (on) => setSoftDrop(on),
      hardDrop: hardDrop,
    ),
  );

  WellGeometry _geo = WellGeometry(1, 1);
  WellGeometry get geometry => _geo;

  double _time = 0;
  double _softHold = 0;
  bool _softRequested = false;
  int _lastHud = -1;
  final List<_Flash> _flashes = [];
  final List<_Popup> _popups = [];

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _geo = WellGeometry(size.x, size.y);
    touch.cellWidth = _geo.cell;
  }

  /// Starts a fresh game on the same renderer.
  void reset(BlockfallGame next) {
    rules = next;
    _flashes.clear();
    _popups.clear();
    _softHold = 0;
    _softRequested = false;
    touch.cancel();
    _lastHud = -1;
    _pump();
  }

  // ------------------------------------------------------------------ input

  void moveLeft() {
    rules.moveLeft();
    _pump();
  }

  void moveRight() {
    rules.moveRight();
    _pump();
  }

  void rotate() {
    rules.rotate();
    _pump();
  }

  void hardDrop() {
    rules.hardDrop();
    _pump();
  }

  bool hold() {
    final ok = rules.hold();
    _pump();
    return ok;
  }

  PowerUpResult usePowerUp(PowerUpType t) {
    final r = rules.usePowerUp(t);
    _pump();
    return r;
  }

  /// Soft drop on/off. With [minSeconds] the soft drop stays on that long even if released
  /// sooner, so a single tap on the soft-drop button still moves the piece down.
  void setSoftDrop(bool on, {double minSeconds = 0}) {
    _softRequested = on;
    if (on) {
      _softHold = max(_softHold, minSeconds);
      rules.softDrop(true);
    } else if (_softHold <= 0) {
      rules.softDrop(false);
    }
  }

  /// Marks the HUD dirty (after stock purchases and the like).
  void refresh() {
    _lastHud = -1;
    _pump();
  }

  // ----------------------------------------------------------------- update

  @override
  void update(double dt) {
    super.update(dt);
    final d = min(dt, 0.1);
    _time += d;
    if (_softHold > 0) {
      _softHold = max(0, _softHold - d);
      if (_softHold == 0 && !_softRequested) rules.softDrop(false);
    }
    for (final f in _flashes) {
      f.age += d;
    }
    _flashes.removeWhere((f) => f.age >= _Flash.life);
    for (final p in _popups) {
      p.age += d;
    }
    _popups.removeWhere((p) => p.age >= _Popup.life);
    rules.tick(d);
    _pump();
  }

  void _pump() {
    for (final e in rules.drainEvents()) {
      if (e is LinesCleared) {
        _flashes.add(_Flash(e.rows, e.prismRows > 0));
        final label = e.perfectClear
            ? 'PERFECT +${e.scoreGained}'
            : '+${e.scoreGained}';
        _popups.add(_Popup(label));
      }
      onEvent?.call(e);
    }
    final hud = Object.hashAll([
      rules.score,
      rules.level,
      rules.lines,
      rules.combo,
      rules.coinsFromPrisms,
      rules.holdPiece?.type,
      rules.canHold,
      rules.isGameOver,
      rules.isPaused,
      rules.slowRemaining.ceil(),
      rules.adRefillsUsed,
      for (final n in rules.next) n.type,
      for (final t in PowerUpType.values)
        rules.stock(t) * 10 + rules.usesThisGame(t),
    ]);
    if (hud != _lastHud) {
      _lastHud = hud;
      revision.value++;
    }
  }

  // ----------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final g = _geo;
    final pulse = (_time * 0.8) % 1.0;
    final slow = rules.slowActive;

    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, g.width, g.height),
      const Radius.circular(14),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xE608141B));
    // Faint grid.
    final grid = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    for (var c = 1; c < BlockfallLayout.cols; c++) {
      final x = g.left + c * g.cell;
      canvas.drawLine(
        Offset(x, g.top),
        Offset(x, g.top + g.wellPixelHeight),
        grid,
      );
    }
    for (var r = 1; r < BlockfallLayout.rows; r++) {
      final y = g.top + r * g.cell;
      canvas.drawLine(
        Offset(g.left, y),
        Offset(g.left + g.wellPixelWidth, y),
        grid,
      );
    }

    final well = rules.well;
    for (var r = WellGeometry.hiddenRows; r < Well.totalRows; r++) {
      for (var c = 0; c < BlockfallLayout.cols; c++) {
        final color = well.colorAt(r, c);
        if (color == 0) continue;
        final o = g.cellOrigin(r, c)!;
        GemPainter.drawGem(
          canvas,
          Rect.fromLTWH(o.$1, o.$2, g.cell, g.cell),
          color,
          prism: well.prismAt(r, c),
          pulse: (pulse + c * 0.13 + r * 0.07) % 1.0,
        );
      }
    }

    final active = rules.currentPiece;
    if (active != null && !rules.isGameOver) {
      if (showGhost && !active.isBomb) {
        final ghost = rules.ghostPiece;
        if (ghost != null && ghost.row != active.row) {
          for (final cell in ghost.cells) {
            final o = g.cellOrigin(cell.row, cell.col);
            if (o == null) continue;
            GemPainter.drawGhost(
              canvas,
              Rect.fromLTWH(o.$1, o.$2, g.cell, g.cell),
              active.type!.colorId,
            );
          }
        }
      }
      _drawActive(canvas, g, active, pulse);
    }

    for (final f in _flashes) {
      final a = (1 - f.age / _Flash.life).clamp(0.0, 1.0);
      final base = f.prism ? const Color(0xFFFFE066) : const Color(0xFFFFFFFF);
      for (final row in f.rows) {
        final o = g.cellOrigin(row, 0);
        if (o == null) continue;
        final rect = Rect.fromLTWH(o.$1, o.$2, g.wellPixelWidth, g.cell);
        canvas.drawRect(
          rect,
          Paint()..color = base.withValues(alpha: 0.85 * a),
        );
        canvas.drawRect(
          rect.inflate(g.cell * 0.3 * (1 - a)),
          Paint()
            ..color = const Color(0xFF39D0F2).withValues(alpha: 0.35 * a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    for (final p in _popups) {
      final a = (1 - p.age / _Popup.life).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            color: const Color(0xFFFFE066).withValues(alpha: a),
            fontSize: g.cell * 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (g.width - tp.width) / 2,
          g.top + g.wellPixelHeight * 0.4 - p.age * g.cell * 3,
        ),
      );
    }

    // Outline last so it frames everything; turns blue while Slow is active.
    canvas.drawRRect(
      panel.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = slow ? 2.5 : 1.5
        ..color = slow ? const Color(0xFF7FD6FF) : const Color(0xAA2EC4B6),
    );
  }

  void _drawActive(
    Canvas canvas,
    WellGeometry g,
    ActivePiece piece,
    double pulse,
  ) {
    for (final cell in piece.cells) {
      final o = g.cellOrigin(cell.row, cell.col);
      if (o == null) continue;
      final rect = Rect.fromLTWH(o.$1, o.$2, g.cell, g.cell);
      if (piece.isBomb) {
        GemPainter.drawBomb(canvas, rect, pulse * 2 % 1.0);
      } else {
        GemPainter.drawGem(
          canvas,
          rect,
          piece.type!.colorId,
          prism: cell.prism,
          pulse: pulse,
        );
      }
    }
  }
}

class _Flash {
  _Flash(this.rows, this.prism);
  static const double life = 0.3;
  final List<int> rows;
  final bool prism;
  double age = 0;
}

class _Popup {
  _Popup(this.text);
  static const double life = 0.9;
  final String text;
  double age = 0;
}

/// Maps a piece type to the small preview cells (col,row), normalised to a tight box.
({List<(int, int)> cells, int cols, int rows, int? prism}) previewCells(
  PieceType type,
  int? prismCell,
) {
  final raw = type.states[0];
  final minC = raw.map((e) => e.$1).reduce(min);
  final minR = raw.map((e) => e.$2).reduce(min);
  final cells = [for (final (c, r) in raw) (c - minC, r - minR)];
  final cols = cells.map((e) => e.$1).reduce(max) + 1;
  final rows = cells.map((e) => e.$2).reduce(max) + 1;
  return (cells: cells, cols: cols, rows: rows, prism: prismCell);
}
