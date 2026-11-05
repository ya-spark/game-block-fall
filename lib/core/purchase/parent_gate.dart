import 'dart:math';

import '../clock.dart';

/// One multiplication question, e.g. `7 x 8`.
class GateQuestion {
  const GateQuestion(this.a, this.b);
  final int a;
  final int b;
  int get answer => a * b;
  String get text => '$a x $b';
}

enum GateResult { correct, wrong, locked }

/// Pure-Dart logic of the parent gate shown before any real-money purchase.
/// Factors are 6 to 9. Three wrong answers in a row lock purchases for 60 s.
class ParentGate {
  ParentGate({Clock? clock, Random? random})
    : _clock = clock ?? DateTime.now,
      _random = random ?? Random();

  static const int minFactor = 6;
  static const int maxFactor = 9;
  static const int maxWrongInRow = 3;
  static const Duration lockDuration = Duration(seconds: 60);

  final Clock _clock;
  final Random _random;
  int _wrongInRow = 0;
  DateTime? _lockedUntil;

  /// Time left on the lock, or null when purchases are not locked.
  Duration? get lockRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(_clock());
    if (left <= Duration.zero) {
      _lockedUntil = null;
      return null;
    }
    return left;
  }

  bool get isLocked => lockRemaining != null;

  /// A fresh question; avoids repeating [previous].
  GateQuestion newQuestion([GateQuestion? previous]) {
    final span = maxFactor - minFactor + 1;
    while (true) {
      final q = GateQuestion(
        minFactor + _random.nextInt(span),
        minFactor + _random.nextInt(span),
      );
      if (previous == null || q.a != previous.a || q.b != previous.b) return q;
    }
  }

  /// Checks a typed answer. After [maxWrongInRow] wrong answers the gate locks.
  GateResult submit(GateQuestion q, String typed) {
    if (isLocked) return GateResult.locked;
    if (int.tryParse(typed.trim()) == q.answer) {
      _wrongInRow = 0;
      return GateResult.correct;
    }
    _wrongInRow++;
    if (_wrongInRow >= maxWrongInRow) {
      _wrongInRow = 0;
      _lockedUntil = _clock().add(lockDuration);
      return GateResult.locked;
    }
    return GateResult.wrong;
  }
}
