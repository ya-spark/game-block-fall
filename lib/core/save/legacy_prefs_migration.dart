import 'package:shared_preferences/shared_preferences.dart';

import '../profile/profile_store.dart';
import 'save_data.dart';

/// Chunk 2 of Blockfall kept the power-up stock, the controls scheme and the ghost toggle
/// in plain SharedPreferences keys. They now live in [SaveData]; this copies any such
/// values into the profile once and deletes the old keys.
Future<bool> migrateLegacyBlockfallPrefs(
  SharedPreferences prefs,
  ProfileStore profile,
) async {
  final keys = [
    'bf.controls',
    'bf.ghost',
    for (final id in kPowerUpIds) 'bf.stock.$id',
  ].where(prefs.containsKey).toList();
  if (keys.isEmpty) return false;

  final stock = <String, int>{
    for (final id in kPowerUpIds) id: ?prefs.getInt('bf.stock.$id'),
  };
  final controls = switch (prefs.getString('bf.controls')) {
    'buttons' => ControlScheme.buttons,
    'touch' => ControlScheme.touch,
    _ => null,
  };
  await profile.importLegacySettings(
    // Types the old prefs never stored keep the fresh-install default of 1.
    powerUps: stock.isEmpty
        ? null
        : {for (final id in kPowerUpIds) id: stock[id] ?? 1},
    controls: controls,
    ghost: prefs.getBool('bf.ghost'),
  );
  for (final k in keys) {
    await prefs.remove(k);
  }
  return true;
}
