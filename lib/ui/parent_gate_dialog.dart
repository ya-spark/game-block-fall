import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/purchase/parent_gate.dart';
import '../core/services.dart';
import 'test_ids.dart';

/// Asks a grown-up to answer a multiplication before a real-money purchase.
/// Returns true only after a correct answer. While purchases are locked it
/// shows a short note instead and returns false.
Future<bool> askParentGate(BuildContext context, Services s) async {
  final gate = s.parentGate;
  final left = gate.lockRemaining;
  if (left != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Purchases are paused. Try again in ${left.inSeconds + 1} s.',
        ),
      ),
    );
    return false;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => ParentGateDialog(gate: gate),
  );
  return ok ?? false;
}

class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key, required this.gate});
  final ParentGate gate;

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog> {
  final _controller = TextEditingController();
  late GateQuestion _question = widget.gate.newQuestion();
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    switch (widget.gate.submit(_question, _controller.text)) {
      case GateResult.correct:
        Navigator.pop(context, true);
      case GateResult.locked:
        Navigator.pop(context, false);
      case GateResult.wrong:
        setState(() {
          _question = widget.gate.newQuestion(_question);
          _wrong = true;
          _controller.clear();
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: TestIds.gateDialog,
    title: const Text('Ask a grown-up'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('This is a purchase with real money. Solve this to go on:'),
        const SizedBox(height: 12),
        Text(
          '${_question.text} = ?',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        if (_wrong)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Not quite. Here is a new one.'),
          ),
        TextField(
          key: TestIds.gateAnswer,
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        key: TestIds.gateCancel,
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: TestIds.gateSubmit,
        onPressed: _submit,
        child: const Text('OK'),
      ),
    ],
  );
}
