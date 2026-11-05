import 'package:blockfall/ui/test_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the question in the open parent gate and returns its right answer.
int gateAnswer(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(TestIds.gateDialog),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .firstWhere((t) => RegExp(r'^\d x \d = \?$').hasMatch(t));
  final m = RegExp(r'^(\d) x (\d)').firstMatch(text)!;
  return int.parse(m[1]!) * int.parse(m[2]!);
}

/// Types [answer] (or the right one when null) and presses OK.
Future<void> answerGate(WidgetTester tester, {int? answer}) async {
  await tester.enterText(
    find.byKey(TestIds.gateAnswer),
    '${answer ?? gateAnswer(tester)}',
  );
  await tester.tap(find.byKey(TestIds.gateSubmit));
  await tester.pumpAndSettle();
}

/// Types a wrong answer and presses OK.
Future<void> answerGateWrong(WidgetTester tester) =>
    answerGate(tester, answer: gateAnswer(tester) + 1);
