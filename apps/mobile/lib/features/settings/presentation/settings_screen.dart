import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/settings_provider.dart';
import '../domain/app_settings.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Settings screen.
///
/// Allows the user to configure:
///   - Device display name
///   - Theme preference
///   - Transfer history visibility
///
/// No network calls. No account. No telemetry.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────
          _SectionHeader(label: 'Appearance'),

          _ThemeTile(
            current: settings.themePreference,
            onChanged: (pref) => notifier.setTheme(pref, ref),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Device ────────────────────────────────────────────────
          _SectionHeader(label: 'Device'),

          _DeviceNameTile(
            currentName: settings.deviceName,
            onSave: notifier.setDeviceName,
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Transfers ─────────────────────────────────────────────
          _SectionHeader(label: 'Transfers'),

          SwitchListTile.adaptive(
            title: const Text('Show transfer history'),
            subtitle:
                const Text('Keep a record of completed transfers this session'),
            value: settings.showTransferHistory,
            onChanged: notifier.setShowHistory,
          ),

          const SizedBox(height: AppTheme.spacingLg),

          // ── About ─────────────────────────────────────────────────
          _SectionHeader(label: 'About'),

          ListTile(
            title: const Text('Version'),
            trailing: Text(AppConstants.appVersion,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),

          ListTile(
            title: const Text('License'),
            trailing: Text('Apache 2.0',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),

          ListTile(
            title: const Text('Privacy'),
            subtitle: const Text(
                'No data leaves this device. No accounts. No telemetry.'),
          ),

          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.current, required this.onChanged});
  final ThemePreference current;
  final void Function(ThemePreference) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingSm),
            SegmentedButton<ThemePreference>(
              segments: ThemePreference.values
                  .map((p) => ButtonSegment(
                        value: p,
                        label: Text(p.label),
                      ))
                  .toList(),
              selected: {current},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceNameTile extends StatefulWidget {
  const _DeviceNameTile({required this.currentName, required this.onSave});
  final String currentName;
  final void Function(String) onSave;

  @override
  State<_DeviceNameTile> createState() => _DeviceNameTileState();
}

class _DeviceNameTileState extends State<_DeviceNameTile> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _save();
    });
  }

  @override
  void didUpdateWidget(_DeviceNameTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentName != widget.currentName) {
      _controller.text = widget.currentName;
    }
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != widget.currentName) {
      widget.onSave(name);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Name',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingSm),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: AppConstants.maxDeviceNameLength,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'e.g. Alice\'s MacBook',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
