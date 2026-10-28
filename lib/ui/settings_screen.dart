import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/services.dart';
import 'blockfall_prefs.dart';
import 'test_ids.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final p = s.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: p,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              key: TestIds.settingsSound,
              title: const Text('Sound'),
              value: p.data.soundOn,
              onChanged: p.setSound,
            ),
            SwitchListTile(
              key: TestIds.settingsVibration,
              title: const Text('Vibration'),
              value: p.data.vibrationOn,
              onChanged: p.setVibration,
            ),
            SwitchListTile(
              key: TestIds.settingsReminders,
              title: const Text('Daily reminder'),
              subtitle: const Text('A local notification at 19:00'),
              value: p.data.remindersOn,
              onChanged: (v) async {
                if (v) {
                  final ok = await s.notifications.requestPermission();
                  if (!ok) return;
                  await s.notifications.scheduleDailyReminder(
                    hour: 19,
                    minute: 0,
                    title: s.config.displayName,
                    body: 'Your daily reward is waiting!',
                  );
                } else {
                  await s.notifications.cancelAll();
                }
                await p.setReminders(v);
              },
            ),
            const _BlockfallSettings(),
            if (s.ads.privacyOptionsRequired)
              ListTile(
                key: TestIds.settingsPrivacy,
                title: const Text('Ad privacy options'),
                onTap: s.ads.showPrivacyOptions,
              ),
            ListTile(
              key: TestIds.settingsPlayGames,
              title: const Text('Google Play Games'),
              subtitle: Text(
                s.identity.isStub
                    ? 'Not connected yet (playing as ${s.identity.current.displayName})'
                    : s.identity.current.displayName,
              ),
            ),
            ListTile(
              title: Text(s.config.displayName),
              subtitle: Text(
                kReleaseMode ? 'Release build' : 'Debug build (test ads only)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controls scheme and ghost toggle (stored in [BlockfallPrefs]).
class _BlockfallSettings extends StatefulWidget {
  const _BlockfallSettings();

  @override
  State<_BlockfallSettings> createState() => _BlockfallSettingsState();
}

class _BlockfallSettingsState extends State<_BlockfallSettings> {
  BlockfallPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    BlockfallPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    final buttons = p?.controls == ControlScheme.buttons;
    return Column(
      children: [
        SwitchListTile(
          key: TestIds.settingsControls,
          title: const Text('On-screen buttons'),
          subtitle: Text(
            buttons
                ? 'Controls: Buttons (left, right, rotate, drop)'
                : 'Controls: Touch (tap rotates, drag moves, fling drops)',
          ),
          value: buttons,
          onChanged: p == null
              ? null
              : (v) async {
                  await p.setControls(
                    v ? ControlScheme.buttons : ControlScheme.touch,
                  );
                  if (mounted) setState(() {});
                },
        ),
        SwitchListTile(
          key: TestIds.settingsGhost,
          title: const Text('Ghost piece'),
          subtitle: const Text('Show where the piece will land'),
          value: p?.ghost ?? true,
          onChanged: p == null
              ? null
              : (v) async {
                  await p.setGhost(v);
                  if (mounted) setState(() {});
                },
        ),
      ],
    );
  }
}
