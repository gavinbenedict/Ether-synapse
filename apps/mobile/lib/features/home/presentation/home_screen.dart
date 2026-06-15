import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'home_provider.dart';
import '../../../shared/models/device_role.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Landing screen — the user chooses whether to send or receive files.
///
/// Appears immediately after the splash screen.
/// Navigates to [SendScreen] or [ReceiveScreen] on confirmation.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      showAppBar: true,
      title: 'Ether Synapse',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => context.pushNamed(AppRouteNames.settings),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // ── Heading ───────────────────────────────────────────────
          Text(
            'What would you like to do?',
            style: tt.headlineSmall?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a role for this session.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // ── Role cards ────────────────────────────────────────────
          _RoleCard(
            role: DeviceRole.sender,
            icon: Icons.upload_rounded,
            selected: state.selectedRole == DeviceRole.sender,
            onTap: () => notifier.selectRole(DeviceRole.sender),
          ),
          const SizedBox(height: AppTheme.spacingMd),
          _RoleCard(
            role: DeviceRole.receiver,
            icon: Icons.download_rounded,
            selected: state.selectedRole == DeviceRole.receiver,
            onTap: () => notifier.selectRole(DeviceRole.receiver),
          ),

          const Spacer(),

          // ── Continue button ───────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: state.selectedRole != null ? 1.0 : 0.0,
            child: FilledButton.icon(
              onPressed: state.selectedRole == null
                  ? null
                  : () => _navigate(context, state.selectedRole!),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, DeviceRole role) {
    switch (role) {
      case DeviceRole.sender:
        context.pushNamed(AppRouteNames.send);
      case DeviceRole.receiver:
        context.pushNamed(AppRouteNames.receive);
    }
  }
}

/// Role selection card widget.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final DeviceRole role;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bg = selected ? cs.primaryContainer : cs.surfaceContainerLow;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    final border = selected
        ? BorderSide(color: cs.primary, width: 2)
        : BorderSide(color: cs.outlineVariant);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.fromBorderSide(border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label,
                          style: tt.titleMedium?.copyWith(color: fg)),
                      const SizedBox(height: 4),
                      Text(
                        role.description,
                        style: tt.bodySmall
                            ?.copyWith(color: fg.withValues(alpha: 0.75)),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
