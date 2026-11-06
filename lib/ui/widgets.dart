import 'package:flutter/material.dart';

import 'home_hero.dart';

/// Friendly palette shared by the kid-facing screens.
class KidColors {
  static const sky1 = Color(0xFF7DD3FC);
  static const sky2 = Color(0xFFC4B5FD);
  static const sky3 = Color(0xFFFDE68A);
  static const sun = Color(0xFFFFC93C);
  static const orange = Color(0xFFFF8A3D);
  static const green = Color(0xFF34D399);
  static const greenDark = Color(0xFF059669);
  static const blue = Color(0xFF38BDF8);
  static const blueDark = Color(0xFF0284C7);
  static const teal = Color(0xFF2DD4BF);
  static const tealDark = Color(0xFF0D9488);
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
    this.icon,
    this.iconWidget,
    required this.label,
    this.color,
  }) : assert(icon != null || iconWidget != null);

  /// Material icon; ignored when [iconWidget] is given (e.g. a [CoinIcon]).
  final IconData? icon;
  final Widget? iconWidget;
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
        iconWidget ?? Icon(icon, size: 24, color: color ?? KidColors.purple),
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

/// A gold coin drawn in code: darker rim, inner ring, soft shine and "MC" in dark gold.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});
  final double size;

  static const Color _gold = Color(0xFFFFC93C);
  static const Color _rim = Color(0xFFD99A0B);
  static const Color _ink = Color(0xFF8A5A00);

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'coins',
    excludeSemantics: true,
    child: SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _gold,
          border: Border.all(color: _rim, width: size * 0.09),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.4, -0.5),
                radius: 0.9,
                colors: [Color(0xFFFFE68A), _gold],
              ),
              border: Border.all(
                color: _rim.withValues(alpha: 0.7),
                width: size * 0.04,
              ),
            ),
            child: Center(
              child: Text(
                'MC',
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
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
    this.compact = false,
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

  /// Half-width variant for the Home 2 x 2 grid: fills the width it is given (64 dp tall),
  /// with a smaller icon and label.
  final bool compact;
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
    final height = widget.primary ? 76.0 : 64.0;
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
                      style: TextStyle(
                        fontSize: widget.primary
                            ? 36
                            : (widget.compact ? 22 : 28),
                      ),
                    )
                  else
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: widget.primary ? 38 : (widget.compact ? 24 : 30),
                    ),
                  SizedBox(width: widget.compact ? 6 : 10),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.primary
                              ? 32
                              : (widget.compact ? 18 : 24),
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
        width: widget.compact ? null : 290,
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

/// Home column height without the hero band and without the gaps: title (~58), stat chips (48),
/// 8 dp spacer, Play (76) and the 2 x 2 grid (2 x 64 + 10).
const double _homeFixedHeight = 58 + 48 + 8 + 76 + 138;

/// Hero band height and spacing between Home groups for [available] dp of height: 160 and 14 when
/// there is room, else spacing 10 and the hero shrinks down to 96.
(double, double) homeLayout(double available) {
  if (available >= _homeFixedHeight + 5 * 14 + HomeHero.maxHeight) {
    return (HomeHero.maxHeight, 14);
  }
  final hero = (available - _homeFixedHeight - 5 * 10).clamp(
    HomeHero.minHeight,
    HomeHero.maxHeight,
  );
  return (hero, 10);
}

/// The Home secondary buttons in rows of two, 10 dp apart, as wide as the Play button (290 dp).
/// A lone last button spans the row, so hidden buttons leave no gap.
class HomeGrid extends StatelessWidget {
  const HomeGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          spacing: 10,
          children: [
            for (final c in children.skip(i).take(2)) Expanded(child: c),
          ],
        ),
      );
    }
    return SizedBox(width: 290, child: Column(spacing: 10, children: rows));
  }
}

/// White rounded card that groups a row on the colorful menu screens.
class KidPanel extends StatelessWidget {
  const KidPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xF2FFFFFF),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(
          listTileTheme: const ListTileThemeData(
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KidColors.ink,
            ),
            subtitleTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: KidColors.ink,
            ),
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// Colorful full-page background with safe-area padding for the menu screens.
class KidPage extends StatelessWidget {
  const KidPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => KidBackground(
    child: SizedBox.expand(child: SafeArea(child: child)),
  );
}
