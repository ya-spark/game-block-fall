import 'package:flutter/widgets.dart';

import '../game/themes/block_theme.dart';

const Duration kThemeFade = Duration(milliseconds: kThemeFadeMs);

/// Calls [builder] with the previous theme, the current one and the fade 0..1 (1 = settled).
/// When [theme] changes the fade restarts; it never blocks input.
class ThemeFade extends StatefulWidget {
  const ThemeFade({super.key, required this.theme, required this.builder});

  final BlockTheme theme;
  final Widget Function(
    BuildContext context,
    BlockTheme from,
    BlockTheme to,
    double t,
  )
  builder;

  @override
  State<ThemeFade> createState() => _ThemeFadeState();
}

class _ThemeFadeState extends State<ThemeFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: kThemeFade,
    value: 1,
  );
  late BlockTheme _from = widget.theme;

  @override
  void didUpdateWidget(ThemeFade old) {
    super.didUpdateWidget(old);
    if (old.theme.id != widget.theme.id) {
      _from = old.theme;
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _fade,
    builder: (context, _) =>
        widget.builder(context, _from, widget.theme, _fade.value),
  );
}

/// Full-screen background of the current theme, cross-fading on a change.
class ThemeBackground extends StatelessWidget {
  const ThemeBackground({super.key, required this.theme, required this.child});

  final BlockTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) => ThemeFade(
    theme: theme,
    builder: (context, from, to, t) =>
        CustomPaint(painter: _BackgroundPainter(from, to, t), child: child),
  );
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.from, this.to, this.t);
  final BlockTheme from;
  final BlockTheme to;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) {
      to.paintBackground(canvas, size);
      return;
    }
    from.paintBackground(canvas, size);
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(255, 255, 255, t),
    );
    to.paintBackground(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.from.id != from.id || old.to.id != to.id || old.t != t;
}
