import 'package:flutter/material.dart';

/// Game-over overlay: a clear dark panel (rounded card, about 90 % opaque, thin light border,
/// soft shadow) so text and buttons never mix with the game background. Order top to bottom:
/// Share icon (top left), title and scores, [buttons] side by side, [leadButton] (Continue)
/// last. An eye button fades the panel out so the final board is visible; a tap anywhere, or
/// the eye button, brings it back.
class GameOverPanel extends StatefulWidget {
  const GameOverPanel({
    super.key,
    required this.title,
    required this.details,
    required this.buttons,
    this.leadButton,
    this.shareButton,
    this.viewKey,
    this.panelKey,
  });

  final String title;

  /// Score, best, medal... shown under the title.
  final List<Widget> details;

  /// Play again and Home, side by side.
  final List<GameOverButton> buttons;

  /// Optional main action (Continue) shown alone, last, at the bottom of the panel.
  final GameOverButton? leadButton;

  /// Share icon button, shown at the top left of the panel.
  final GameOverButton? shareButton;

  final Key? viewKey;
  final Key? panelKey;

  /// Soft shadow for text on ghost buttons.
  static List<Shadow> get outline => const [
    Shadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Solid dark surface at about 90 % opacity.
  static const Color surface = Color(0xE6140B2B);

  @override
  State<GameOverPanel> createState() => _GameOverPanelState();
}

class _GameOverPanelState extends State<GameOverPanel> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: widget.panelKey,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: GameOverPanel.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x66FFFFFF), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (widget.shareButton != null) widget.shareButton!,
              const Spacer(),
              // Room for the eye button, which sits on top of the faded card.
              const SizedBox(width: 44, height: 44),
            ],
          ),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF3A0), Color(0xFFFFB300)],
            ).createShader(r),
            child: Text(
              widget.title.toUpperCase(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.details,
            ),
          ),
          const SizedBox(height: 14),
          // Play again and Home always side by side; the buttons shrink on narrow screens.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Flexible(child: widget.buttons[i]),
              ],
            ],
          ),
          if (widget.leadButton != null) ...[
            const SizedBox(height: 14),
            widget.leadButton!,
          ],
        ],
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Tap anywhere brings the panel back.
          if (_hidden)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _hidden = false),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Stack(
                  children: [
                    IgnorePointer(
                      ignoring: _hidden,
                      child: AnimatedOpacity(
                        opacity: _hidden ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: card,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        key: widget.viewKey,
                        tooltip: _hidden ? 'Show panel' : 'View board',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF3A2A5C),
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(
                          _hidden ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GameOverButtonKind { primary, secondary, ghost }

/// Glossy pill button: gold for the main action, purple-pink for secondary, dark glass for ghost.
/// Colours keep at least 4.5:1 contrast between text and button.
class GameOverButton extends StatelessWidget {
  const GameOverButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
    this.kind = GameOverButtonKind.secondary,
    this.fontSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
  }) : assert(label != null || icon != null);

  /// Null for an icon-only button (then [semanticLabel] names it).
  final String? label;
  final String? semanticLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GameOverButtonKind kind;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final (colors, fg, border) = switch (kind) {
      GameOverButtonKind.primary => (
        const [Color(0xFFFFE259), Color(0xFFFF8F00)],
        const Color(0xFF3B1F00),
        const Color(0xFFFFF3A0),
      ),
      GameOverButtonKind.secondary => (
        const [Color(0xFF6A3AC4), Color(0xFFB0307A)],
        Colors.white,
        const Color(0xFFFFD6F2),
      ),
      GameOverButtonKind.ghost => (
        const [Color(0xFF3A2A5C), Color(0xFF2E2150)],
        Colors.white,
        const Color(0xCCFFFFFF),
      ),
    };
    final enabled = onPressed != null;
    return Semantics(
      label: semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onPressed,
              child: Padding(
                padding: padding,
                // Shrinks the content on very narrow screens instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: fontSize + 4, color: fg),
                        if (label != null) const SizedBox(width: 6),
                      ],
                      if (label != null)
                        Text(
                          label!,
                          style: TextStyle(
                            color: fg,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
