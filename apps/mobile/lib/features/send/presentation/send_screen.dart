import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'send_provider.dart';
import '../../../shared/models/peer_device.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../../services/system_settings_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';

/// Send mode screen.
///
/// Scans for nearby devices in Receive mode (advertising Ether Synapse payloads).
/// Tapping a receiver navigates to the negotiation screen.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sendProvider.notifier).startScanning();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sendProvider.notifier).startScanning();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(sendProvider.notifier).stopScanning();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Find a Receiver',
      leading: BackButton(onPressed: () => context.pop()),
      actions: [
        if (!state.isScanning)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Scan again',
            onPressed: () =>
                ref.read(sendProvider.notifier).startScanning(),
          ),
      ],
      padding: EdgeInsets.zero,
      body: PermissionGate(
        condition: state.bluetoothEnabled,
        title: 'Bluetooth Required',
        subtitle:
            'Enable Bluetooth to scan for nearby receivers.',
        actionLabel: 'Enable Bluetooth',
        settingsAction: SystemSettingsService.actionBluetooth,
        onAction: () => ref.read(sendProvider.notifier).startScanning(),
        child: Column(
          children: [
            // ── Scanning banner ─────────────────────────────────
            _ScanningBanner(isScanning: state.isScanning),

            // ── Error ────────────────────────────────────────────
            if (state.hasError)
              _ErrorBanner(
                error: state.error!,
                onRetry: () =>
                    ref.read(sendProvider.notifier).startScanning(),
              )
            // ── Receiver list ────────────────────────────────────
            else if (state.hasReceivers)
              Expanded(
                child: _ReceiverList(
                  receivers: state.sortedReceivers,
                  onTap: (peer) => context.pushNamed(
                    AppRouteNames.negotiate,
                    pathParameters: {'peerId': peer.id},
                  ),
                ),
              )
            // ── Empty state ──────────────────────────────────────
            else
              Expanded(
                child: Center(
                  child: Padding(
                    padding: AppTheme.pagePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.isScanning
                              ? Icons.bluetooth_searching_rounded
                              : Icons.bluetooth_disabled_rounded,
                          size: 72,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        Text(
                          state.isScanning
                              ? 'Scanning for receivers…'
                              : 'No receivers found',
                          style: tt.titleMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppTheme.spacingXs),
                        Text(
                          'Make sure the other device has opened\n'
                          'Ether Synapse and selected "Receive Files".',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ScanningBanner extends StatelessWidget {
  const _ScanningBanner({required this.isScanning});
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isScanning ? 40 : 0,
      color: cs.primaryContainer,
      child: isScanning
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Scanning for receivers…',
                  style: tt.labelMedium
                      ?.copyWith(color: cs.onPrimaryContainer),
                ),
              ],
            )
          : null,
    );
  }
}

class _ReceiverList extends StatelessWidget {
  const _ReceiverList({required this.receivers, required this.onTap});
  final List<PeerDevice> receivers;
  final void Function(PeerDevice) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppTheme.pagePadding,
      itemCount: receivers.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTheme.spacingXs),
      itemBuilder: (context, i) {
        final peer = receivers[i];
        return _ReceiverCard(peer: peer, onTap: () => onTap(peer));
      },
    );
  }
}

class _ReceiverCard extends StatelessWidget {
  const _ReceiverCard({required this.peer, required this.onTap});
  final PeerDevice peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final platformIcon = switch (peer.platform) {
      PeerPlatform.android => Icons.android_rounded,
      PeerPlatform.ios => Icons.phone_iphone_rounded,
      PeerPlatform.macos => Icons.laptop_mac_rounded,
      PeerPlatform.windows => Icons.desktop_windows_rounded,
      PeerPlatform.linux => Icons.terminal_rounded,
      PeerPlatform.unknown => Icons.devices_rounded,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // Platform avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(platformIcon,
                    size: 24, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peer.displayName ?? peer.name, style: tt.titleSmall),
                    Text(
                      '${peer.platform.label}${peer.remoteCapabilities != null ? " • ${peer.remoteCapabilities!.deviceName}" : ""}',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (peer.signalStrength != null)
                      Text(
                        '${peer.signalStrength} dBm',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Receive mode badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Receiving',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onPrimaryContainer, fontSize: 10),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: AppTheme.pagePadding,
      child: Card(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.warning_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error,
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onErrorContainer)),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text('Retry',
                    style: TextStyle(color: cs.onErrorContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
