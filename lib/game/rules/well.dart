/// The playfield: 10 columns, 20 visible rows plus 2 hidden rows above (rows 0 and 1).
///
/// Row 0 is the top of the hidden zone, row [totalRows] - 1 is the bottom row.
/// A cell holds a color id (0 = empty, 1..7 = gem color) and a prism flag.
class Well {
  Well()
    : _colors = List.filled(cols * totalRows, 0),
      _prism = List.filled(cols * totalRows, false);

  /// Builds a well from text rows, aligned to the bottom. `.` is empty, `1`..`7` is a
  /// color, `a`..`g` is color 1..7 with a prism. Handy for tests and debug hooks.
  factory Well.fromRows(List<String> rows) {
    final w = Well();
    final start = totalRows - rows.length;
    if (start < 0) throw ArgumentError('too many rows');
    for (var i = 0; i < rows.length; i++) {
      final s = rows[i];
      if (s.length != cols) throw ArgumentError('row must have $cols cells');
      for (var c = 0; c < cols; c++) {
        final ch = s[c];
        if (ch == '.') continue;
        final code = ch.codeUnitAt(0);
        if (code >= 0x31 && code <= 0x37) {
          w.set(start + i, c, code - 0x30);
        } else if (code >= 0x61 && code <= 0x67) {
          w.set(start + i, c, code - 0x60, prism: true);
        } else {
          throw ArgumentError('bad cell char "$ch"');
        }
      }
    }
    return w;
  }

  static const int cols = 10;
  static const int visibleRows = 20;
  static const int hiddenRows = 2;
  static const int totalRows = visibleRows + hiddenRows;

  final List<int> _colors;
  final List<bool> _prism;

  static bool inBounds(int row, int col) =>
      row >= 0 && row < totalRows && col >= 0 && col < cols;

  /// Color id at the cell (0 when empty).
  int colorAt(int row, int col) => _colors[row * cols + col];
  bool prismAt(int row, int col) => _prism[row * cols + col];
  bool isFilled(int row, int col) => _colors[row * cols + col] != 0;

  void set(int row, int col, int color, {bool prism = false}) {
    _colors[row * cols + col] = color;
    _prism[row * cols + col] = color != 0 && prism;
  }

  void clearCell(int row, int col) => set(row, col, 0);

  bool isRowFull(int row) {
    for (var c = 0; c < cols; c++) {
      if (!isFilled(row, c)) return false;
    }
    return true;
  }

  bool rowHasPrism(int row) {
    for (var c = 0; c < cols; c++) {
      if (prismAt(row, c)) return true;
    }
    return false;
  }

  int prismCountInRow(int row) {
    var n = 0;
    for (var c = 0; c < cols; c++) {
      if (prismAt(row, c)) n++;
    }
    return n;
  }

  bool get isEmpty => _colors.every((c) => c == 0);

  /// Removes the given rows; rows above fall by the number of removed rows below them.
  void removeRows(Iterable<int> rows) {
    final gone = rows.toSet();
    if (gone.isEmpty) return;
    var write = totalRows - 1;
    for (var read = totalRows - 1; read >= 0; read--) {
      if (gone.contains(read)) continue;
      if (write != read) _copyRow(read, write);
      write--;
    }
    for (var r = write; r >= 0; r--) {
      _blankRow(r);
    }
  }

  /// Empties rows `[from, to)`.
  void clearRowRange(int from, int to) {
    for (var r = from; r < to; r++) {
      _blankRow(r);
    }
  }

  void _copyRow(int from, int to) {
    for (var c = 0; c < cols; c++) {
      _colors[to * cols + c] = _colors[from * cols + c];
      _prism[to * cols + c] = _prism[from * cols + c];
    }
  }

  void _blankRow(int r) {
    for (var c = 0; c < cols; c++) {
      _colors[r * cols + c] = 0;
      _prism[r * cols + c] = false;
    }
  }

  /// Text form of the whole well (same alphabet as [Well.fromRows]), top to bottom.
  List<String> toRows() => [
    for (var r = 0; r < totalRows; r++)
      [
        for (var c = 0; c < cols; c++)
          if (!isFilled(r, c))
            '.'
          else if (prismAt(r, c))
            String.fromCharCode(0x60 + colorAt(r, c))
          else
            '${colorAt(r, c)}',
      ].join(),
  ];

  Well copy() {
    final w = Well();
    for (var i = 0; i < _colors.length; i++) {
      w._colors[i] = _colors[i];
      w._prism[i] = _prism[i];
    }
    return w;
  }
}
