import 'piece_type.dart';

/// A piece type plus the optional prism cell chosen when it was generated.
class PieceSpec {
  const PieceSpec(this.type, {this.prismCell});
  final PieceType type;

  /// Index (0..3) into the piece's cell list, or null for a plain piece.
  final int? prismCell;

  @override
  String toString() => 'PieceSpec(${type.name}, prism: $prismCell)';
}

/// One occupied cell of the falling piece.
class PieceCell {
  const PieceCell(this.row, this.col, {this.prism = false});
  final int row;
  final int col;
  final bool prism;

  @override
  bool operator ==(Object other) =>
      other is PieceCell &&
      other.row == row &&
      other.col == col &&
      other.prism == prism;

  @override
  int get hashCode => Object.hash(row, col, prism);

  @override
  String toString() => '($row,$col${prism ? ',prism' : ''})';
}

/// The falling piece (or the single-cell bomb when [spec] is null). Immutable.
class ActivePiece {
  const ActivePiece({
    required this.spec,
    required this.rotation,
    required this.col,
    required this.row,
  });

  /// Single-cell bomb whose cell is at ([row], [col]).
  const ActivePiece.bomb({required this.row, required this.col})
    : spec = null,
      rotation = 0;

  final PieceSpec? spec;

  /// Rotation state 0..3.
  final int rotation;

  /// Box origin (top-left) in well coordinates. For the bomb: the cell itself.
  final int col;
  final int row;

  bool get isBomb => spec == null;
  PieceType? get type => spec?.type;

  /// The 4 occupied cells in well coordinates (1 cell for the bomb).
  List<PieceCell> get cells {
    final s = spec;
    if (s == null) return [PieceCell(row, col)];
    final offsets = s.type.states[rotation];
    return [
      for (var i = 0; i < offsets.length; i++)
        PieceCell(
          row + offsets[i].$2,
          col + offsets[i].$1,
          prism: s.prismCell == i,
        ),
    ];
  }

  ActivePiece shifted(int dCol, int dRow) => ActivePiece(
    spec: spec,
    rotation: rotation,
    col: col + dCol,
    row: row + dRow,
  );

  ActivePiece rotatedClockwise() =>
      ActivePiece(spec: spec, rotation: (rotation + 1) % 4, col: col, row: row);
}
