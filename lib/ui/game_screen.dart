import 'package:flutter/material.dart';

import '../core/services.dart';
import 'test_ids.dart';

/// TODO(chunk 2): temporary placeholder. The Flame renderer, gestures, HUD, power-up bar,
/// pause/game-over dialogs and revive flow are built on top of `BlockfallGame`
/// (`lib/game/rules/blockfall_game.dart`) in the next chunk.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    return Scaffold(
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      key: TestIds.gameBack,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      '${s.profile.data.bestScore}',
                      key: TestIds.gameBest,
                      style: const TextStyle(color: Color(0xFFFFC145)),
                    ),
                  ],
                ),
              ),
              const Text(
                '0',
                key: TestIds.gameScore,
                style: TextStyle(color: Colors.white, fontSize: 44),
              ),
              const Expanded(
                child: Center(
                  key: TestIds.gameWidget,
                  child: Text(
                    'Blockfall - game screen coming soon',
                    style: TextStyle(color: Color(0xFFCFE9EC)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
