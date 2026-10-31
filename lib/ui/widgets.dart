import 'package:flutter/material.dart';

/// Friendly palette shared by the kid-facing screens.
class KidColors {
  static const sky1 = Color(0xFF7DD3FC);
  static const sky2 = Color(0xFFC4B5FD);
  static const sky3 = Color(0xFFFBCFE8);
  static const sun = Color(0xFFFFC93C);
  static const orange = Color(0xFFFF8A3D);
  static const green = Color(0xFF34D399);
  static const greenDark = Color(0xFF059669);
  static const blue = Color(0xFF38BDF8);
  static const blueDark = Color(0xFF0284C7);
  static const pink = Color(0xFFF472B6);
  static const pinkDark = Color(0xFFDB2777);
  static const purple = Color(0xFFA78BFA);
  static const purpleDark = Color(0xFF7C3AED);
  static const ink = Color(0xFF3B2A6B);
}

/// Soft rainbow-ish background used behind kid-facing screens.
class KidBackground extends StatelessWidget {
  const KidBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KidColors.sky1, KidColors.sky2, KidColors.sky3],
      ),
    ),
    child: child,
  );
}

/// Plays once on first build: scales up with a little bounce (finite, so tests settle).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.7, end: 1),
    duration: Duration(milliseconds: 450 + index * 90),
    curve: Curves.elasticOut,
    builder: (context, v, c) => Transform.scale(scale: v, child: c),
    child: child,
  );
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color ?? KidColors.purple, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color ?? KidColors.purple),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: KidColors.ink,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class MenuButton extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.primary = false,
    this.emoji,
    this.top = KidColors.blue,
    this.bottom = KidColors.blueDark,
    this.index = 0,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool primary;
  final String? emoji;
  final Color top;
  final Color bottom;
  final int index;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.primary ? 80.0 : 60.0;
    final button = AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: const Duration(milliseconds: 90),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [widget.top, widget.bottom],
          ),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 6,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.emoji != null)
                    Text(
                      widget.emoji!,
                      style: TextStyle(fontSize: widget.primary ? 36 : 28),
                    )
                  else
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.primary ? 38 : 30,
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.primary ? 32 : 24,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return PopIn(
      index: widget.index,
      child: SizedBox(
        width: 300,
        height: height,
        child: _BadgeDot(
          show: widget.badge,
          size: 18,
          backgroundColor: Colors.redAccent,
          child: SizedBox.expand(child: button),
        ),
      ),
    );
  }
}

/// Small notification dot on a button's corner. Unlike [Badge] it never takes part
/// in hit testing, so the button underneath stays tappable.
class _BadgeDot extends StatelessWidget {
  const _BadgeDot({
    required this.show,
    required this.size,
    required this.backgroundColor,
    required this.child,
  });
  final bool show;
  final double size;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(child: child),
      if (show)
        Positioned(
          top: -2,
          right: 6,
          child: IgnorePointer(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
    ],
  );
}
