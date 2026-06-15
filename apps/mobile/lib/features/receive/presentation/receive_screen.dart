import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'receive_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../../services/system_settings_service.dart';
import '../../../core/theme/app_theme.dart';

/// Receive mode screen.
///
/// Shows this device's advertising status and waits for a sender to
/// discover it and initiate a transfer negotiation.
///
/// BLE advertising starts automatically on screen entry.
/// Screen wake-lock is requested to keep the display on while waiting.
class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiveProvider.notifier).startReceiving();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(receiveProvider.notifier).startReceiving();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(receiveProvider.notifier).stopReceiving();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(receiveProvider.notifier).stopReceiving();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(receiveProvider);
    final deviceName = ref.watch(deviceNameProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Ready to Receive',
      leading: BackButton(onPressed: () => context.pop()),
      body: PermissionGate(
        condition: state.bluetoothEnabled,
        title: 'Bluetooth Required',
        subtitle:
            'Enable Bluetooth so nearby senders can discover this device.',
        actionLabel: 'Enable Bluetooth',
        settingsAction: SystemSettingsService.actionBluetooth,
        onAction: () =>
            ref.read(receiveProvider.notifier).startReceiving(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),

            // ── Pulsing ready indicator ──────────────────────────
            Center(child: _AdvertisingPulse(isAdvertising: state.isAdvertising)),

            const SizedBox(height: AppTheme.spacingXxl),

            // ── Device name ───────────────────────────────────────
            Center(
              child: Text(
                deviceName,
                style: tt.headlineMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Center(
              child: Text(
                state.isAdvertising
                    ? 'This device is visible to nearby senders'
                    : 'Starting advertising…',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppTheme.spacingXxl),

            // ── Status chips ──────────────────────────────────────
            _StatusChips(state: state),

            const Spacer(),

            // ── Error ─────────────────────────────────────────────
            if (state.hasError)
              _ErrorCard(
                error: state.error!,
                onRetry: () =>
                    ref.read(receiveProvider.notifier).startReceiving(),
              ),

            const SizedBox(height: AppTheme.spacingXxl),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AdvertisingPulse extends StatefulWidget {
  const _AdvertisingPulse({required this.isAdvertising});
  final bool isAdvertising;

  @override
  State<_AdvertisingPulse> createState() => _AdvertisingPulseState();
}

class _AdvertisingPulseState extends State<_AdvertisingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.isAdvertising;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) => Transform.scale(
        scale: active ? _scale.value : 1.0,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
          ),
          child: Icon(
            active
                ? Icons.bluetooth_searching_rounded
                : Icons.bluetooth_disabled_rounded,
            size: 64,
            color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.state});
  final ReceiveState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingSm,
      children: [
        _Chip(
          icon: Icons.bluetooth_rounded,
          label: state.bluetoothEnabled ? 'Bluetooth On' : 'Bluetooth Off',
          active: state.bluetoothEnabled,
          cs: cs,
          tt: tt,
        ),
        _Chip(
          icon: Icons.cell_tower_rounded,
          label: state.isAdvertising ? 'Advertising' : 'Not Advertising',
          active: state.isAdvertising,
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final bool active;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final bg = active ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fg = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: tt.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: cs.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onErrorContainer)),
              ),
            ]),
            const SizedBox(height: AppTheme.spacingSm),
            TextButton(
              onPressed: onRetry,
              child: Text('Retry',
                  style: TextStyle(color: cs.onErrorContainer)),
            ),
          ],
        ),
      ),
    );
  }
}
