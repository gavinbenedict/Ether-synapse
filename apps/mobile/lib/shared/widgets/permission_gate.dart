import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/system_settings_service.dart';

/// A permission/state gate that blocks its [child] behind an action card
/// when a required system condition is not met.
///
/// Usage:
/// ```dart
/// PermissionGate(
///   condition: bluetoothEnabled,
///   title: 'Bluetooth Required',
///   subtitle: 'Enable Bluetooth to discover nearby devices.',
///   actionLabel: 'Enable Bluetooth',
///   settingsAction: SystemSettingsService.actionBluetooth,
///   child: MyScreen(),
/// )
/// ```
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.condition,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.settingsAction,
    required this.child,
    this.icon,
    this.onAction,
  });

  /// Show [child] when true; show the gate card when false.
  final bool condition;

  /// Short title on the gate card (e.g. "Bluetooth Required").
  final String title;

  /// Longer explanation (e.g. "Enable Bluetooth to discover nearby devices.").
  final String subtitle;

  /// Label for the action button (e.g. "Enable Bluetooth").
  final String actionLabel;

  /// Passed to [SystemSettingsService.open] when the button is tapped.
  final String settingsAction;

  /// Optional icon override. Defaults to a warning icon.
  final IconData? icon;

  /// Optional callback called after the settings intent is fired.
  final VoidCallback? onAction;

  /// Content shown when [condition] is true.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (condition) return child;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: AppTheme.pagePadding,
        child: Card(
          color: cs.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ?? Icons.warning_rounded,
                  size: 48,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  subtitle,
                  style:
                      tt.bodyMedium?.copyWith(color: cs.onErrorContainer),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(
                  onPressed: () {
                    SystemSettingsService.open(settingsAction);
                    onAction?.call();
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onErrorContainer,
                    foregroundColor: cs.errorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
