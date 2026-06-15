import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../presentation/settings_provider.dart';
import '../domain/app_settings.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

/// Settings screen.
///
/// Allows the user to configure:
///   - Appearance (theme)
///   - Device name (persisted via SharedPreferences)
///   - Bluetooth status & permissions
///   - Transfer history visibility
///
/// No network calls. No account. No telemetry.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Permission/BT status values loaded asynchronously.
  bool? _btScanGranted;
  bool? _btConnectGranted;
  bool? _btAdvertiseGranted;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final advertise = await Permission.bluetoothAdvertise.status;
    if (mounted) {
      setState(() {
        _btScanGranted = scan.isGranted;
        _btConnectGranted = connect.isGranted;
        _btAdvertiseGranted = advertise.isGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────
          _SectionHeader(label: 'Appearance', icon: Icons.palette_rounded),

          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppTheme.spacingMd),
                SegmentedButton<ThemePreference>(
                  segments: ThemePreference.values
                      .map((p) => ButtonSegment(
                            value: p,
                            icon: Icon(_themeIcon(p), size: 16),
                            label: Text(p.label),
                          ))
                      .toList(),
                  selected: {settings.themePreference},
                  onSelectionChanged: (s) => notifier.setTheme(s.first, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Device ────────────────────────────────────────────────
          _SectionHeader(label: 'Device', icon: Icons.phone_android_rounded),

          _SettingsCard(
            child: _DeviceNameTile(
              currentName: settings.deviceName,
              onSave: notifier.setDeviceName,
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Bluetooth & Permissions ───────────────────────────────
          _SectionHeader(
            label: 'Bluetooth & Permissions',
            icon: Icons.bluetooth_rounded,
          ),

          _SettingsCard(
            child: Column(
              children: [
                _PermissionTile(
                  label: 'Bluetooth Scan',
                  description: 'Required to discover nearby devices',
                  granted: _btScanGranted,
                ),
                const Divider(height: 1),
                _PermissionTile(
                  label: 'Bluetooth Connect',
                  description: 'Required to connect to paired devices',
                  granted: _btConnectGranted,
                ),
                const Divider(height: 1),
                _PermissionTile(
                  label: 'Bluetooth Advertise',
                  description: 'Required for this device to be discoverable',
                  granted: _btAdvertiseGranted,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh permissions'),
                  onPressed: _refreshPermissions,
                ),
                if (_btScanGranted == false ||
                    _btConnectGranted == false ||
                    _btAdvertiseGranted == false) ...[
                  const SizedBox(height: AppTheme.spacingSm),
                  FilledButton.icon(
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('Open App Settings'),
                    onPressed: () => openAppSettings(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Transfers ─────────────────────────────────────────────
          _SectionHeader(
            label: 'Transfers',
            icon: Icons.swap_horiz_rounded,
          ),

          _SettingsCard(
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show transfer history'),
              subtitle: const Text(
                  'Keep a record of completed transfers this session'),
              value: settings.showTransferHistory,
              onChanged: notifier.setShowHistory,
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── About ─────────────────────────────────────────────────
          _SectionHeader(label: 'About', icon: Icons.info_outline_rounded),

          _SettingsCard(
            child: Column(
              children: [
                _InfoTile(
                  label: 'Version',
                  value: AppConstants.appVersion,
                ),
                const Divider(height: 1),
                _InfoTile(
                  label: 'License',
                  value: 'Apache 2.0',
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline_rounded,
                      color: cs.onSurfaceVariant, size: 20),
                  title: const Text('Privacy'),
                  subtitle: const Text(
                    'No data leaves this device. No accounts. No telemetry.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }

  IconData _themeIcon(ThemePreference pref) => switch (pref) {
        ThemePreference.system => Icons.brightness_auto_rounded,
        ThemePreference.light => Icons.light_mode_rounded,
        ThemePreference.dark => Icons.dark_mode_rounded,
      };
}

// ── Shared layout widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: child,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.label,
    required this.description,
    required this.granted,
  });
  final String label;
  final String description;
  final bool? granted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final IconData icon;
    final Color color;
    final String statusText;

    if (granted == null) {
      icon = Icons.hourglass_empty_rounded;
      color = cs.onSurfaceVariant;
      statusText = 'Checking…';
    } else if (granted!) {
      icon = Icons.check_circle_rounded;
      color = cs.primary;
      statusText = 'Granted';
    } else {
      icon = Icons.cancel_rounded;
      color = cs.error;
      statusText = 'Denied';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.bodyMedium),
                Text(
                  description,
                  style:
                      tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            statusText,
            style: tt.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Device name sub-widget ────────────────────────────────────────────────────

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
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _dirty) _save();
    });
    _controller.addListener(() {
      setState(() => _dirty = _controller.text.trim() != widget.currentName);
    });
  }

  @override
  void didUpdateWidget(_DeviceNameTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentName != widget.currentName &&
        !_focusNode.hasFocus) {
      _controller.text = widget.currentName;
      _dirty = false;
    }
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != widget.currentName) {
      widget.onSave(name);
      setState(() => _dirty = false);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Name',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          'Shown to nearby devices during discovery',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLength: AppConstants.maxDeviceNameLength,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            hintText: "e.g. Alice's Phone",
            counterText: '',
            suffixIcon: _dirty
                ? IconButton(
                    icon: const Icon(Icons.check_rounded),
                    tooltip: 'Save',
                    onPressed: _save,
                  )
                : const Icon(Icons.edit_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}
