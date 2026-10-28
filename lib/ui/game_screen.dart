import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/services.dart';
import '../game/flame/blockfall_flame_game.dart';
import '../game/flame/blockfall_layout.dart';
import '../game/rules/blockfall_game.dart';
import '../game/rules/events.dart';
import '../game/rules/powerups.dart';
import 'blockfall_prefs.dart';
import 'hud_widgets.dart';
import 'test_ids.dart';

/// `--dart-define=BLOCKFALL_SEED=<int>` fixes the bag order and prism placement.
const int kBlockfallSeed = int.fromEnvironment(
  'BLOCKFALL_SEED',
  defaultValue: -1,
);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.game});

  /// Injectable for tests (seeded rules, preloaded well).
  final BlockfallGame? game;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  BlockfallFlameGame? _flame;
  BlockfallPrefs? _prefs;
  Services? _s;
  bool _started = false;
  bool _recorded = false;
  bool _dialogOpen = false;
  bool _sheetOpen = false;
  bool _paused = false;
  int _gameIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = ServicesScope.of(context);
    if (!_started) {
      _started = true;
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _persistStock();
    _flame?.onEvent = null;
    _flame?.revision.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await BlockfallPrefs.load();
    if (!mounted) return;
    _prefs = prefs;
    final rules = widget.game ?? _newRules();
    final flame = BlockfallFlameGame(rules: rules, showGhost: prefs.ghost)
      ..onEvent = _onEvent;
    setState(() => _flame = flame);
  }

  BlockfallGame _newRules() {
    final stock = _prefs!.stock;
    if (kBlockfallSeed >= 0) {
      return BlockfallGame.seeded(kBlockfallSeed + _gameIndex, stock: stock);
    }
    return BlockfallGame(random: Random(), stock: stock);
  }

  // ----------------------------------------------------------- pause logic

  void _syncPause() {
    final f = _flame;
    if (f == null) return;
    f.rules.isPaused = _paused || _sheetOpen;
    f.touch.cancel();
    f.setSoftDrop(false);
    f.refresh();
  }

  void _pause() {
    final f = _flame;
    if (f == null || f.rules.isGameOver || _dialogOpen) return;
    setState(() => _paused = true);
    _syncPause();
  }

  void _resume() {
    setState(() => _paused = false);
    _syncPause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  // ------------------------------------------------------------ game events

  void _onEvent(GameEvent e) {
    final s = _s;
    if (s == null) return;
    final vib = s.profile.data.vibrationOn;
    switch (e) {
      case PieceLocked():
        if (vib) HapticFeedback.lightImpact();
      case LinesCleared():
        if (vib) HapticFeedback.mediumImpact();
      case PowerUpUsed():
        _persistStock();
      case GameOver():
        _persistStock();
        _showGameOver();
      default:
        break;
    }
  }

  void _persistStock() {
    final f = _flame;
    final p = _prefs;
    if (f == null || p == null) return;
    p.saveStock({for (final t in PowerUpType.values) t: f.rules.stock(t)});
  }

  Future<void> _finishGame() async {
    if (_recorded) return;
    final s = _s!;
    final g = _flame!.rules;
    if (g.piecesPlaced == 0 && g.score == 0 && !g.isGameOver) return;
    _recorded = true;
    _persistStock();
    if (g.coinsFromPrisms > 0) await s.profile.addCoins(g.coinsFromPrisms);
    final unlocked = await s.profile.recordGameFinished(
      GameSummary(
        score: g.score,
        linesCleared: g.lines,
        piecesPlaced: g.piecesPlaced,
        maxCombo: g.maxCombo,
      ),
    );
    await s.leaderboard.submitScore(
      s.config.playGames.leaderboardHighScore,
      g.score,
    );
    for (final a in unlocked) {
      await s.leaderboard.unlockAchievement(a.id);
    }
    s.analytics.logEvent('game_over', {'score': g.score});
    if (unlocked.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')} '
            '(+${unlocked.fold<int>(0, (n, a) => n + a.reward)} coins)',
          ),
        ),
      );
    }
  }

  Future<void> _showGameOver() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    final s = _s!;
    final flame = _flame!;
    final game = flame.rules;
    final best = max(s.profile.data.bestScore, game.score);
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: TestIds.gameOverDialog,
        title: const Text('Game over'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueNode(
              key: TestIds.gameOverScore,
              value: '${game.score}',
              child: Text(
                'Score ${game.score}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Best $best'),
            if (game.score >= best && game.score > 0)
              const Text(
                'New best!',
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          if (game.canRevive)
            FilledButton.icon(
              key: TestIds.gameOverRevive,
              icon: const Icon(Icons.smart_display),
              label: const Text('Revive (watch ad)'),
              onPressed: () => Navigator.pop(ctx, 'revive'),
            ),
          TextButton(
            key: TestIds.gameOverRetry,
            onPressed: () => Navigator.pop(ctx, 'retry'),
            child: const Text('Play again'),
          ),
          TextButton(
            key: TestIds.gameOverHome,
            onPressed: () => Navigator.pop(ctx, 'home'),
            child: const Text('Home'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    switch (action) {
      case 'revive':
        final earned = await s.ads.showRewarded(AdPlacement.revive);
        if (!mounted) return;
        if (earned && game.revive()) {
          flame.refresh();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad not available. Try again later.')),
        );
        _showGameOver();
      case 'retry':
        await _finishGame();
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (!mounted) return;
        _gameIndex++;
        _recorded = false;
        setState(() => _paused = false);
        flame.reset(_newRules());
        _syncPause();
      default:
        await _finishGame();
        await s.ads.maybeShowInterstitialAfterGameOver();
        if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _leave() async {
    await _finishGame();
    if (mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------- power-ups

  Future<void> _onPowerUp(PowerUpType t) async {
    final f = _flame;
    if (f == null || _paused || f.rules.isGameOver) return;
    final rules = f.rules;
    if (rules.stock(t) <= 0) {
      if (rules.usesThisGame(t) >= PowerUpRules.maxUsesPerTypePerGame) {
        _snack('${PowerUpButton.title(t)} is used up for this game');
        return;
      }
      await _openRefill(t);
      return;
    }
    final r = f.usePowerUp(t);
    if (r == PowerUpResult.limitReached) {
      _snack('Max ${PowerUpRules.maxUsesPerTypePerGame} uses per game');
    }
    _persistStock();
  }

  Future<void> _openRefill(PowerUpType t) async {
    final f = _flame!;
    final s = _s!;
    _sheetOpen = true;
    _syncPause();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F2430),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Text(
                'Out of ${PowerUpButton.title(t)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                key: TestIds.gameRefillCoins,
                icon: const Icon(Icons.monetization_on),
                label: Text('Buy with coins (${t.price})'),
                onPressed: () => Navigator.pop(ctx, 'coins'),
              ),
              OutlinedButton.icon(
                key: TestIds.gameRefillAd,
                icon: const Icon(Icons.smart_display),
                label: Text('Watch ad for +1 (${f.rules.adRefillsLeft} left)'),
                onPressed: f.rules.adRefillsLeft > 0
                    ? () => Navigator.pop(ctx, 'ad')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    _sheetOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'coins':
        if (await s.profile.spendCoins(t.price)) {
          f.rules.addStock(t);
        } else {
          _snack('Not enough coins (${t.price} needed)');
        }
      case 'ad':
        // TODO(chunk 3): AdPlacement has no power-up refill value yet (lib/core).
        final earned = await s.ads.showRewarded(AdPlacement.gameOver);
        if (earned && !f.rules.refillWithAd(t)) {
          _snack('No more ad refills this game');
        } else if (!earned) {
          _snack('Ad not available. Try again later.');
        }
    }
    _persistStock();
    if (mounted) {
      _syncPause();
      f.refresh();
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final flame = _flame;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1),
              radius: 1.4,
              colors: [Color(0xFF1D4552), Color(0xFF0F2430), Color(0xFF0A1822)],
              stops: [0, 0.55, 1],
            ),
          ),
          child: SafeArea(
            child: flame == null
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: IconButton.filledTonal(
                        key: TestIds.gameBack,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: flame.revision,
                        builder: (context, _, _) => _buildPlay(context, flame),
                      ),
                      if (_paused) _buildPauseOverlay(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlay(BuildContext context, BlockfallFlameGame flame) {
    final s = _s!;
    final rules = flame.rules;
    final buttons = _prefs?.controls == ControlScheme.buttons;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              IconButton.filledTonal(
                key: TestIds.gameBack,
                icon: const Icon(Icons.chevron_left),
                onPressed: _leave,
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: s.profile,
                builder: (context, _) =>
                    _BestChip(best: max(s.profile.data.bestScore, rules.score)),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: TestIds.gamePause,
                icon: const Icon(Icons.pause),
                onPressed: _pause,
              ),
            ],
          ),
        ),
        ScorePill(score: rules.score),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) =>
                _buildMiddle(BlockfallLayout(c.maxWidth, c.maxHeight), flame),
          ),
        ),
        const SizedBox(height: 4),
        _StreakBar(
          streak: s.profile.displayStreak,
          showStreak: s.config.retention.streaks,
          combo: rules.combo,
          prismCoins: rules.coinsFromPrisms,
        ),
        if (buttons) _buildControls(flame),
        const SizedBox(height: 6),
        _buildPowerUps(flame),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMiddle(BlockfallLayout l, BlockfallFlameGame flame) {
    final rules = flame.rules;
    final touch = _prefs?.controls != ControlScheme.buttons;
    Widget well = SizedBox(
      width: l.wellWidth,
      height: l.wellHeight,
      child: GameWidget<BlockfallFlameGame>(
        key: TestIds.gameWidget,
        game: flame,
      ),
    );
    well = _WellInput(
      key: TestIds.gameWell,
      flame: flame,
      enabled: touch,
      child: well,
    );
    final hold = rules.holdPiece;
    final holdBox = GestureDetector(
      key: TestIds.gameHold,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_paused) return;
        flame.hold();
      },
      child: ValueNode(
        key: TestIds.gameHoldPiece,
        value: hold?.type.displayName ?? 'empty',
        label: 'Hold',
        child: HudBox(
          label: 'HOLD',
          width: l.sideWidth,
          height: l.bigBoxHeight,
          child: hold == null
              ? const SizedBox.shrink()
              : PiecePreview(
                  type: hold.type,
                  prismCell: hold.prismCell,
                  cell: l.miniCell(l.sideWidth),
                  dim: !rules.canHold,
                ),
        ),
      ),
    );
    final next = rules.next;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: l.sideWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                holdBox,
                ValueNode(
                  key: TestIds.gameLevel,
                  value: '${rules.level}',
                  label: 'Level',
                  child: StatPanel(
                    label: 'LEVEL',
                    value: rules.level,
                    width: l.sideWidth,
                  ),
                ),
                ValueNode(
                  key: TestIds.gameGoal,
                  value: '${rules.goal}',
                  label: 'Goal',
                  child: StatPanel(
                    label: 'GOAL',
                    value: rules.goal,
                    width: l.sideWidth,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: l.gap),
          well,
          SizedBox(width: l.gap),
          SizedBox(
            width: l.sideWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                for (var i = 0; i < next.length; i++)
                  ValueNode(
                    key: TestIds.gameNext(i),
                    value: next[i].type.displayName,
                    label: 'Next ${i + 1}',
                    child: HudBox(
                      label: i == 0 ? 'NEXT' : '',
                      width: l.sideWidth,
                      height: i == 0 ? l.bigBoxHeight : l.smallBoxHeight,
                      child: PiecePreview(
                        type: next[i].type,
                        prismCell: next[i].prismCell,
                        cell: l.miniCell(l.sideWidth) * (i == 0 ? 1 : 0.8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BlockfallFlameGame f) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        ControlButton(
          key: TestIds.gameCtlLeft,
          icon: Icons.arrow_left,
          label: 'Move left',
          repeat: true,
          onPress: f.moveLeft,
        ),
        ControlButton(
          key: TestIds.gameCtlRotate,
          icon: Icons.rotate_right,
          label: 'Rotate',
          onPress: f.rotate,
        ),
        ControlButton(
          key: TestIds.gameCtlRight,
          icon: Icons.arrow_right,
          label: 'Move right',
          repeat: true,
          onPress: f.moveRight,
        ),
        ControlButton(
          key: TestIds.gameCtlSoftDrop,
          icon: Icons.keyboard_arrow_down,
          label: 'Soft drop',
          onPress: () => f.setSoftDrop(true, minSeconds: 0.15),
          onRelease: () => f.setSoftDrop(false),
        ),
        ControlButton(
          key: TestIds.gameCtlHardDrop,
          icon: Icons.keyboard_double_arrow_down,
          label: 'Hard drop',
          onPress: f.hardDrop,
        ),
      ],
    ),
  );

  Widget _buildPowerUps(BlockfallFlameGame f) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 18,
    children: [
      for (final t in PowerUpType.values)
        PowerUpButton(
          type: t,
          stock: f.rules.stock(t),
          active: t == PowerUpType.slow && f.rules.slowActive,
          caption: t == PowerUpType.slow && f.rules.slowActive
              ? '${f.rules.slowRemaining.ceil()}s'
              : null,
          onTap: () => _onPowerUp(t),
        ),
    ],
  );

  Widget _buildPauseOverlay() => Positioned.fill(
    child: Container(
      color: const Color(0xE60A1822),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(
              fontSize: 30,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(
            width: 240,
            height: 52,
            child: FilledButton.icon(
              key: TestIds.gamePauseResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              onPressed: _resume,
            ),
          ),
          SizedBox(
            width: 240,
            height: 52,
            child: OutlinedButton.icon(
              key: TestIds.gamePauseQuit,
              icon: const Icon(Icons.home),
              label: const Text('Home'),
              onPressed: _leave,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Feeds raw pointer events on the well into the pure-Dart [TouchControls].
class _WellInput extends StatefulWidget {
  const _WellInput({
    super.key,
    required this.flame,
    required this.enabled,
    required this.child,
  });
  final BlockfallFlameGame flame;
  final bool enabled;
  final Widget child;

  @override
  State<_WellInput> createState() => _WellInputState();
}

class _WellInputState extends State<_WellInput> {
  int? _pointer;
  VelocityTracker? _velocity;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) {
      if (!widget.enabled || _pointer != null || widget.flame.rules.isPaused) {
        return;
      }
      _pointer = e.pointer;
      _velocity = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.position);
      widget.flame.touch.pointerDown(
        e.position.dx,
        e.position.dy,
        e.timeStamp.inMilliseconds,
      );
    },
    onPointerMove: (e) {
      if (e.pointer != _pointer) return;
      _velocity?.addPosition(e.timeStamp, e.position);
      widget.flame.touch.pointerMove(e.position.dx, e.position.dy);
    },
    onPointerUp: (e) {
      if (e.pointer != _pointer) return;
      _velocity?.addPosition(e.timeStamp, e.position);
      final v = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
      _pointer = null;
      widget.flame.touch.pointerUp(
        e.position.dx,
        e.position.dy,
        e.timeStamp.inMilliseconds,
        v,
      );
    },
    onPointerCancel: (e) {
      if (e.pointer != _pointer) return;
      _pointer = null;
      widget.flame.touch.cancel();
    },
    child: widget.child,
  );
}

class _BestChip extends StatelessWidget {
  const _BestChip({required this.best});
  final int best;

  @override
  Widget build(BuildContext context) => ValueNode(
    key: TestIds.gameBest,
    value: '$best',
    label: 'Best score',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: kGold, size: 18),
          const SizedBox(width: 6),
          Text(
            '$best',
            style: const TextStyle(color: kGold, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

/// Streak (daily play streak), current combo and prism coins earned this game.
class _StreakBar extends StatelessWidget {
  const _StreakBar({
    required this.streak,
    required this.showStreak,
    required this.combo,
    required this.prismCoins,
  });
  final int streak;
  final bool showStreak;
  final int combo;
  final int prismCoins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFCFE9EC), fontSize: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            if (showStreak)
              Row(
                key: TestIds.gameStreak,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: Color(0xFFFF6B5E),
                  ),
                  const SizedBox(width: 4),
                  Text('Day $streak streak'),
                ],
              ),
            ValueNode(
              key: TestIds.gameCombo,
              value: '$combo',
              label: 'Combo',
              child: Text(combo > 0 ? 'Combo x$combo' : 'Combo -'),
            ),
            if (prismCoins > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond, size: 16, color: Color(0xFF39D0F2)),
                  const SizedBox(width: 3),
                  Text('+$prismCoins'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
