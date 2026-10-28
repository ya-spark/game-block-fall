/// Pure scoring helpers. All numbers come from the spec (section 3).
const List<int> lineBaseScores = [0, 100, 300, 500, 800];

const int linesPerLevel = 10;
const int comboStep = 50;
const int perfectClearBonus = 1000;
const int softDropPointsPerRow = 1;
const int hardDropPointsPerRow = 2;
const int prismCoinCapPerGame = 40;
const int prismEveryNthPiece = 4;

int levelForLines(int totalLines) => 1 + totalLines ~/ linesPerLevel;

/// Lines still needed to reach the next level.
int goalForLines(int totalLines) => linesPerLevel - totalLines % linesPerLevel;

/// Score of one line clear, without combo and perfect clear bonuses.
///
/// [rows] is the number of cleared rows (1..4), [prismRows] how many of them contain a
/// prism (their share is doubled), [level] the level before any level-up from this clear.
int lineClearScore({
  required int rows,
  required int prismRows,
  required int level,
  required bool backToBack,
}) {
  final base = lineBaseScores[rows] * level;
  final extra = (base * prismRows / rows).round();
  var total = base + extra;
  if (backToBack && rows == 4) total = total * 3 ~/ 2;
  return total;
}

int comboBonus({required int combo, required int level}) =>
    combo >= 2 ? comboStep * (combo - 1) * level : 0;
