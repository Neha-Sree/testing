import 'package:flutter/material.dart';

import '../doctor_theme.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  bool _push = true;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: DoctorTheme.primary)),
        SwitchListTile(
          title: const Text('Clinical notifications'),
          subtitle: const Text('Placeholder — local prefs only'),
          value: _push,
          onChanged: (v) => setState(() => _push = v),
        ),
        SwitchListTile(
          title: const Text('Dark mode preview'),
          subtitle: const Text('Does not persist globally in this build'),
          value: _dark,
          onChanged: (v) => setState(() => _dark = v),
        ),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Change password'),
          subtitle: const Text('TODO: wire to auth when available'),
          onTap: () {},
        ),
      ],
    );
  }
}
