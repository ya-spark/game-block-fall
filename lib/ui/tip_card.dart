import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services.dart';
import 'test_ids.dart';

/// A small tip card with a "Don't show tips again" checkbox and a Close (X) button.
/// Close alone hides this tip for now; with the box ticked it turns tips off everywhere
/// (the same saved profile value as the Settings "Show tips" switch).
class TipCard extends StatefulWidget {
  const TipCard({
    super.key,
    required this.text,
    required this.onClose,
    this.title,
  });

  final String text;

  /// Optional heading, e.g. "Tip of the day".
  final String? title;

  /// Called after the card was closed (and tips turned off if the box was ticked).
  final VoidCallback onClose;

  @override
  State<TipCard> createState() => _TipCardState();
}

/// A [TipCard] that hides itself once closed, can fade in after [showAfter] and can hide
/// itself again after [hideAfter] (one-time hints).
class TimedTip extends StatefulWidget {
  const TimedTip({
    super.key,
    required this.text,
    this.cardKey,
    this.title,
    this.showAfter = Duration.zero,
    this.hideAfter,
    this.onClose,
  });

  /// Test ID of the visible card (absent while the tip is not shown).
  final Key? cardKey;

  final String text;
  final String? title;
  final Duration showAfter;
  final Duration? hideAfter;
  final VoidCallback? onClose;

  @override
  State<TimedTip> createState() => _TimedTipState();
}

class _TimedTipState extends State<TimedTip> {
  Timer? _show;
  Timer? _hide;
  bool _visible = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    if (widget.showAfter == Duration.zero) {
      _visible = true;
      _armHide();
    } else {
      _show = Timer(widget.showAfter, () {
        if (!mounted) return;
        setState(() => _visible = true);
        _armHide();
      });
    }
  }

  void _armHide() {
    final d = widget.hideAfter;
    if (d == null) return;
    _hide = Timer(d, () {
      if (mounted) {
        setState(() => _closed = true);
        widget.onClose?.call();
      }
    });
  }

  @override
  void dispose() {
    _show?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_closed || !_visible) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: TipCard(
        key: widget.cardKey,
        title: widget.title,
        text: widget.text,
        onClose: () {
          setState(() => _closed = true);
          widget.onClose?.call();
        },
      ),
    );
  }
}

class _TipCardState extends State<TipCard> {
  bool _dontShow = false;

  Future<void> _close() async {
    if (_dontShow) {
      await ServicesScope.of(context).profile.setTipsEnabled(false);
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Material(
        color: const Color(0xF2FFFFFF),
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 6),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Color(0xFF2B1B4D), fontSize: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null)
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            Text(
                              widget.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: TestIds.tipClose,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _close,
                    ),
                  ],
                ),
                InkWell(
                  key: TestIds.tipDontShow,
                  onTap: () => setState(() => _dontShow = !_dontShow),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Checkbox(
                          value: _dontShow,
                          visualDensity: VisualDensity.compact,
                          onChanged: (v) =>
                              setState(() => _dontShow = v ?? false),
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          "Don't show tips again",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
