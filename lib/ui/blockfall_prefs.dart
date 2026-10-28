import 'package:shared_preferences/shared_preferences.dart';

import '../game/rules/powerups.dart';

enum ControlScheme { touch, buttons }

/// Blockfall-specific settings and the power-up stock, kept in SharedPreferences because
/// `SaveData` (lib/core) has no fields for them yet.
///
/// TODO(chunk 3): move the stock into `SaveData` (so it syncs with the cloud save) and the
/// two settings next to the other profile settings.
class BlockfallPrefs {
  BlockfallPrefs._(this._p);

  static Future<BlockfallPrefs> load() async =>
      BlockfallPrefs._(await SharedPreferences.getInstance());

  final SharedPreferences _p;

  static const _controlsKey = 'bf.controls';
  static const _ghostKey = 'bf.ghost';
  static String _stockKey(PowerUpType t) => 'bf.stock.${t.name}';

  /// `--dart-define=BLOCKFALL_CONTROLS=buttons` sets the default scheme (bot / tests).
  static const String _defaultControls = String.fromEnvironment(
    'BLOCKFALL_CONTROLS',
    defaultValue: 'touch',
  );

  ControlScheme get controls {
    final v = _p.getString(_controlsKey) ?? _defaultControls;
    return v == 'buttons' ? ControlScheme.buttons : ControlScheme.touch;
  }

  Future<void> setControls(ControlScheme v) =>
      _p.setString(_controlsKey, v.name);

  bool get ghost => _p.getBool(_ghostKey) ?? true;
  Future<void> setGhost(bool v) => _p.setBool(_ghostKey, v);

  /// Saved power-up stock; a fresh install starts with 1 of each.
  Map<PowerUpType, int> get stock => {
    for (final t in PowerUpType.values) t: _p.getInt(_stockKey(t)) ?? 1,
  };

  Future<void> saveStock(Map<PowerUpType, int> stock) async {
    for (final e in stock.entries) {
      await _p.setInt(_stockKey(e.key), e.value < 0 ? 0 : e.value);
    }
  }
}
