import 'dart:math';
import 'dart:ui';

/// Draws the glossy gem blocks, the prism glow and the bomb. Only `dart:ui`, so the same
/// code paints the Flame well and the small HOLD / NEXT previews.
abstract final class GemPainter {
  /// Gem colors for color ids 1..7 (Bar, Cube, Prong, Zig, Zag, Hook, Boot).
  static const List<Color> palette = [
    Color(0xFF808080), // 0 unused
    Color(0xFF39D0F2), // 1 cyan
    Color(0xFFFFC145), // 2 gold
    Color(0xFF9A7BFF), // 3 violet
    Color(0xFF7FDB5A), // 4 green
    Color(0xFFFF5F57), // 5 red
    Color(0xFF3F7CFF), // 6 blue
    Color(0xFFFF9340), // 7 orange
  ];

  static Color colorOf(int id) => palette[id.clamp(1, 7)];

  static final Map<(int, int), _GemPaints> _cache = {};

  static _GemPaints _paints(int colorId, double size) {
    final key = (colorId, size.round());
    return _cache.putIfAbsent(key, () => _GemPaints(colorOf(colorId), size));
  }

  /// One gem filling [cell]. [pulse] (0..1) animates the prism sparkle.
  static void drawGem(
    Canvas canvas,
    Rect cell,
    int colorId, {
    bool prism = false,
    double pulse = 0,
  }) {
    final size = cell.width;
    final p = _paints(colorId, size);
    canvas.save();
    canvas.translate(cell.left, cell.top);
    canvas.drawRRect(p.body, p.bodyPaint);
    canvas.drawRRect(p.facet, p.facetPaint);
    canvas.drawRRect(p.body, p.edgePaint);
    canvas.drawCircle(p.specCenter, size * 0.075, p.specPaint);
    canvas.drawCircle(
      Offset(size * 0.38, size * 0.2),
      size * 0.035,
      p.specPaint,
    );
    canvas.restore();
    if (prism) drawPrismGlow(canvas, cell, pulse);
  }

  /// Bright white-cyan sparkle core over a gem.
  static void drawPrismGlow(Canvas canvas, Rect cell, double pulse) {
    final s = cell.width;
    final c = cell.center;
    final k = 0.75 + 0.25 * sin(pulse * 2 * pi);
    final glow = Paint()
      ..shader = Gradient.radial(
        c,
        s * 0.62 * k,
        const [Color(0xFFFFFFFF), Color(0x88B8F6FF), Color(0x0039D0F2)],
        const [0.0, 0.4, 1.0],
      );
    canvas.drawCircle(c, s * 0.62 * k, glow);
    canvas.drawCircle(c, s * 0.12, Paint()..color = const Color(0xFFFFFFFF));
    final ray = Paint()
      ..color = const Color(0xCCFFFFFF)
      ..strokeWidth = max(1, s * 0.05)
      ..strokeCap = StrokeCap.round;
    final r = s * 0.3 * k;
    canvas.drawLine(c.translate(-r, 0), c.translate(r, 0), ray);
    canvas.drawLine(c.translate(0, -r), c.translate(0, r), ray);
  }

  /// Faint outline where the piece would land.
  static void drawGhost(Canvas canvas, Rect cell, int colorId) {
    final color = colorOf(colorId);
    final r = RRect.fromRectAndRadius(
      cell.deflate(cell.width * 0.09),
      Radius.circular(cell.width * 0.22),
    );
    canvas.drawRRect(r, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawRRect(
      r,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cell.width * 0.07),
    );
  }

  /// The single-cell Bomb piece: dark glossy sphere, hot ring, fuse spark.
  static void drawBomb(Canvas canvas, Rect cell, double pulse) {
    final s = cell.width;
    final c = cell.center;
    final k = 0.5 + 0.5 * sin(pulse * 2 * pi);
    canvas.drawCircle(
      c,
      s * 0.62,
      Paint()
        ..shader = Gradient.radial(c, s * 0.62, [
          Color.fromARGB((90 + 80 * k).round(), 255, 120, 40),
          const Color(0x00FF7828),
        ]),
    );
    final r = s * 0.36;
    canvas.drawCircle(
      c.translate(0, s * 0.04),
      r,
      Paint()
        ..shader = Gradient.radial(
          c.translate(-r * 0.4, -r * 0.3),
          r * 1.5,
          const [Color(0xFF5B6770), Color(0xFF1B232A), Color(0xFF0A0E12)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawCircle(
      c.translate(0, s * 0.04),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, s * 0.05)
        ..color = const Color(0xFFFF8A3D),
    );
    canvas.drawCircle(
      c.translate(-r * 0.4, -r * 0.35),
      s * 0.06,
      Paint()..color = const Color(0xCCFFFFFF),
    );
    final fuseStart = c.translate(r * 0.55, -r * 0.7);
    final fuseEnd = c.translate(r * 0.95, -r * 1.25);
    canvas.drawLine(
      fuseStart,
      fuseEnd,
      Paint()
        ..color = const Color(0xFFC9A66B)
        ..strokeWidth = max(1.5, s * 0.07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      fuseEnd,
      s * (0.07 + 0.05 * k),
      Paint()..color = const Color(0xFFFFE066),
    );
  }
}

class _GemPaints {
  _GemPaints(Color color, double size) {
    final r = Radius.circular(size * 0.24);
    final box = Rect.fromLTWH(0, 0, size, size);
    body = RRect.fromRectAndRadius(box.deflate(size * 0.05), r);
    facet = RRect.fromRectAndRadius(
      Rect.fromLTWH(size * 0.17, size * 0.14, size * 0.66, size * 0.4),
      Radius.circular(size * 0.16),
    );
    bodyPaint = Paint()
      ..shader = Gradient.linear(
        box.topLeft,
        box.bottomRight,
        [
          _mix(color, const Color(0xFFFFFFFF), 0.38),
          color,
          _darker(color, 0.4),
        ],
        const [0.0, 0.5, 1.0],
      );
    facetPaint = Paint()
      ..shader = Gradient.linear(
        Offset(0, size * 0.14),
        Offset(0, size * 0.54),
        const [Color(0x55FFFFFF), Color(0x00FFFFFF)],
      );
    edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, size * 0.05)
      ..color = _darker(color, 0.55);
    specPaint = Paint()..color = const Color(0xE6FFFFFF);
    specCenter = Offset(size * 0.3, size * 0.27);
  }

  late final RRect body;
  late final RRect facet;
  late final Paint bodyPaint;
  late final Paint facetPaint;
  late final Paint edgePaint;
  late final Paint specPaint;
  late final Offset specCenter;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  static Color _darker(Color c, double t) =>
      Color.lerp(c, const Color(0xFF000000), t)!;
}
