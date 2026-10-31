# Block Fall

Block Fall is a single-player falling-blocks puzzle for Android, built with Flutter and Flame.
Glossy gem pieces drop into a 10-wide well. Fill a row and it clears. Hold a piece, peek at the
next three, race the speed through 15 levels, and use three power-ups (Sweep, Slow, Bomb) when
the stack gets high. The original twist is the **prism**: some pieces carry one glowing gem, and
clearing a row that contains it doubles that row's score and pays coins.

It is fully client-side: no backend, no account, playable offline. Ads are optional to remove with
a one-time purchase; rewarded ads (power-up refill, revive) always stay optional.

The contract for the game is [`docs/SPEC.md`](docs/SPEC.md).

## Controls

Two schemes, switched in Settings (default: Touch).

| Touch (default)                         | Buttons                                   |
|-----------------------------------------|-------------------------------------------|
| Tap the well: rotate clockwise          | On-screen left, right, rotate             |
| Drag sideways: move one column per cell | Soft drop (hold) and hard drop buttons    |
| Slow drag down: soft drop               |                                           |
| Fast fling down: hard drop              |                                           |

Both: tap the HOLD box to hold (once per piece); the three power-up buttons sit under the well.
With 0 stock a power-up button offers "Buy with coins" (Sweep 60, Slow 40, Bomb 50) or "Watch ad
for +1". The back arrow and the pause button stop the game; leaving the app auto-pauses.

## Code layout

```
lib/game/rules/   pure-Dart rules (no Flutter/Flame/Android): well, pieces, bag, gravity,
                  scoring, hold, power-ups, game state machine (BlockfallGame)
lib/game/flame/   Flame renderer, layout math, touch-gesture math
lib/ui/           screens (home, game, daily reward, challenges, shop, settings), HUD widgets,
                  test IDs in test_ids.dart
lib/core/         shared services behind interfaces (ads, purchase, save, identity, leaderboard,
                  notifications, analytics, remote config) and retention (daily reward, streaks,
                  daily challenges, achievements); SaveData is versioned with migrations
app.config.yaml   package name, display name, theme, AdMob IDs (test IDs in debug), ad pacing
products.yaml     in-app products: remove_ads, coins_500
```

Game and UI code never import a vendor SDK; they use the interfaces in `lib/core`.

## Run

```bash
flutter pub get
flutter run                          # debug build: Google TEST ads only
# deterministic game and button controls (what the bot uses):
flutter run --dart-define=BLOCKFALL_SEED=7 --dart-define=BLOCKFALL_CONTROLS=buttons
```

## Tests and checks

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test                         # rules, core, widget and seeded end-to-end bot tests
bash scripts/ad_safety_check.sh
bash scripts/check_asset_licenses.sh
bash scripts/no_secrets_check.sh
# on a device or emulator (manual CI job; hosted runners cannot boot one):
flutter test integration_test/blockfall_bot_test.dart -d <device>
```

The bot script lives in `test/helpers/blockfall_scenario.dart`. The same script runs as a plain
widget test (`test/ui/e2e_bot_test.dart`, part of `flutter test`) and as the integration test on a
device. It finds everything by the keys in `lib/ui/test_ids.dart` and reads state from Semantics
values (score, level, goal, combo, hold piece, next pieces, power-up counts).

## Play Games

Sign-in, saved games, achievements and the leaderboard are stubs that fall back to local storage
until the Play Console IDs are created and put into `app.config.yaml`.
