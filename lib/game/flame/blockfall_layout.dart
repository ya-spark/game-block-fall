import 'dart:math';

/// Screen geometry in plain doubles so it can be unit tested without Flutter.
///
/// [BlockfallLayout] sizes the middle band of the game screen (HOLD / well / NEXT);
/// [WellGeometry] maps well cells to pixels inside the Flame canvas.
class BlockfallLayout {
  BlockfallLayout(this.width, this.height) {
    sideWidth = (width * 0.18).clamp(52.0, 92.0);
    gap = max(4.0, width * 0.02);
    final availW = width - 2 * (sideWidth + gap);
    cell = max(4.0, min((availW - 2 * pad) / cols, (height - 2 * pad) / rows));
  }

  static const int cols = 10;
  static const int rows = 20;

  /// Padding between the well panel edge and the cells.
  static const double pad = 6;

  final double width;
  final double height;

  late final double sideWidth;
  late final double gap;
  late final double cell;

  double get wellWidth => cell * cols + 2 * pad;
  double get wellHeight => cell * rows + 2 * pad;

  /// HOLD box and the first NEXT box.
  double get bigBoxHeight => sideWidth * 0.9;

  /// NEXT boxes 2 and 3.
  double get smallBoxHeight => sideWidth * 0.62;

  /// Cell size used for the miniature pieces inside a box of the given width.
  double miniCell(double boxWidth) => boxWidth / 5.2;

  /// Whole columns a horizontal travel of [dx] pixels is worth.
  int columnsFor(double dx) => (dx.abs() / cell + 1e-6).floor();
}

/// Cell to pixel mapping inside the well canvas. Rows 0-1 of the rules well are hidden, so
/// canvas row 0 is well row [hiddenRows].
class WellGeometry {
  WellGeometry(this.width, this.height) {
    cell = max(
      1.0,
      min(
        (width - 2 * BlockfallLayout.pad) / BlockfallLayout.cols,
        (height - 2 * BlockfallLayout.pad) / BlockfallLayout.rows,
      ),
    );
    left = (width - cell * BlockfallLayout.cols) / 2;
    top = (height - cell * BlockfallLayout.rows) / 2;
  }

  static const int hiddenRows = 2;

  final double width;
  final double height;
  late final double cell;
  late final double left;
  late final double top;

  double get wellPixelWidth => cell * BlockfallLayout.cols;
  double get wellPixelHeight => cell * BlockfallLayout.rows;

  /// Top-left corner of the rules-well cell, or null for hidden rows.
  (double, double)? cellOrigin(int row, int col) {
    final r = row - hiddenRows;
    if (r < 0 || r >= BlockfallLayout.rows) return null;
    return (left + col * cell, top + r * cell);
  }
}

/// Thresholds and the tolerance of the touch scheme (spec section 7).
abstract final class GestureThresholds {
  /// Movement under this many pixels still counts as a tap.
  static const double tapMaxMove = 10;
  static const int tapMaxMillis = 250;

  /// Downward velocity at or above this (px/s) is a hard drop.
  static const double flingVelocity = 1200;
}
