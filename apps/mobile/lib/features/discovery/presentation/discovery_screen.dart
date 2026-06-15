import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/discovery_provider.dart';
import '../domain/discovery_state.dart';
import '../../../shared/models/peer_device.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';

/// Discovery screen — main screen of the application.
///
/// Shows:
///   - BLE status row (Bluetooth state, advertising, scanning, device count).
///   - Deduplicated, signal-sorted list of discovered peers.
///   - Empty state when no peers are found.
///   - Error state if discovery fails, with a retry action.
///
/// Navigates to [PairingScreen] when a peer is selected.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).startDiscovery();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(discoveryProvider.notifier).startDiscovery();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        ref.read(discoveryProvider.notifier).stopDiscovery();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);

    return AppScaffold(
      title: 'Nearby Devices',
      actions: [
        if (!state.isScanning)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(discoveryProvider.notifier).startDiscovery(),
          ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => context.pushNamed(AppRouteNames.settings),
        ),
      ],
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          // ── Status row ────────────────────────────────────────────
          _StatusRow(state: state),

          // ── Error banner ─────────────────────────────────────────
          if (state.hasError)
            _ErrorBanner(
              error: state.error!,
              onRetry: () =>
                  ref.read(discoveryProvider.notifier).startDiscovery(),
            )
          // ── Peer list ─────────────────────────────────────────────
          else if (state.hasPeers)
            Expanded(
              child: _PeerList(
                state: state,
                onTapPeer: (peer) => context.goNamed(
                  AppRouteNames.pairing,
                  pathParameters: {'peerId': peer.id},
                ),
              ),
            )
          // ── Empty state ───────────────────────────────────────────
          else
            Expanded(
              child: _EmptyState(state: state),
            ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Compact status row showing BT / advertising / scanning indicators.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.state});
  final DiscoveryState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: AppConstants.microAnimationDuration,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      color: cs.surfaceContainerLow,
      child: Row(
        children: [
          // Bluetooth enabled indicator
          _StatusChip(
            icon: state.bluetoothEnabled
                ? Icons.bluetooth_rounded
                : Icons.bluetooth_disabled_rounded,
            label: state.bluetoothEnabled ? 'BT On' : 'BT Off',
            active: state.bluetoothEnabled,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(width: AppTheme.spacingSm),

          // Advertising indicator
          _StatusChip(
            icon: Icons.cell_tower_rounded,
            label: 'Advertising',
            active: state.isAdvertising,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(width: AppTheme.spacingSm),

          // Scanning indicator
          _StatusChip(
            icon: Icons.radar_rounded,
            label: 'Scanning',
            active: state.isScanning,
            loading: state.isScanning,
            cs: cs,
            tt: tt,
          ),

          const Spacer(),

          // Device count
          Text(
            '${state.peers.length} device${state.peers.length == 1 ? '' : 's'}',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.tt,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool loading;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final bg = active ? cs.primaryContainer : cs.surfaceContainerHigh;
    final fg = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: AppConstants.statusFadeDuration,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: fg,
                  ),
                )
              : Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: fg, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PeerList extends StatelessWidget {
  const _PeerList({required this.state, required this.onTapPeer});
  final DiscoveryState state;
  final void Function(PeerDevice) onTapPeer;

  @override
  Widget build(BuildContext context) {
    final peers = state.sortedPeers;
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: AppTheme.pagePadding,
        itemCount: peers.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingXs),
        itemBuilder: (context, i) {
          final peer = peers[i];
          return _PeerCard(
            peer: peer,
            onTap: () => onTapPeer(peer),
          );
        },
      ),
    );
  }
}

/// Rich peer card with name, platform, signal, ID, and last-seen.
class _PeerCard extends StatelessWidget {
  const _PeerCard({required this.peer, required this.onTap});
  final PeerDevice peer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // Platform icon
              _PlatformAvatar(platform: peer.platform, cs: cs),
              const SizedBox(width: AppTheme.spacingMd),

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(peer.name, style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      peer.platform.label,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${peer.id}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // Signal + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (peer.signalStrength != null) ...[
                    _SignalBars(
                      normalized: peer.signalStrengthNormalized ?? 0,
                      cs: cs,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${peer.signalStrength} dBm',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformAvatar extends StatelessWidget {
  const _PlatformAvatar({required this.platform, required this.cs});
  final PeerPlatform platform;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final icon = switch (platform) {
      PeerPlatform.android => Icons.android_rounded,
      PeerPlatform.ios => Icons.phone_iphone_rounded,
      PeerPlatform.macos => Icons.laptop_mac_rounded,
      PeerPlatform.windows => Icons.desktop_windows_rounded,
      PeerPlatform.linux => Icons.terminal_rounded,
      PeerPlatform.unknown => Icons.devices_rounded,
    };
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Icon(icon, size: 24, color: cs.onSecondaryContainer),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.normalized, required this.cs});
  final double normalized;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final bars = (normalized * 3).ceil().clamp(0, 3);
    final color = normalized > 0.6
        ? cs.primary
        : normalized > 0.3
            ? cs.tertiary
            : cs.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final h = 6.0 + (i * 3);
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Container(
            width: 4,
            height: h,
            decoration: BoxDecoration(
              color: i < bars ? color : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: cs.onErrorContainer),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      error,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Open Settings / Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});
  final DiscoveryState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
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
                  ? 'Looking for nearby devices…'
                  : 'No devices found',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'Make sure the other device has Ether Synapse open\n'
              'and is within Bluetooth range.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (!state.isAdvertising && state.bluetoothEnabled) ...[
              const SizedBox(height: AppTheme.spacingMd),
              FilledButton.tonal(
                onPressed: null, // controlled by lifecycle
                child: const Text('Advertising inactive'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Expose AppConstants for use in _StatusRow without a new import.
class AppConstants {
  static const microAnimationDuration = Duration(milliseconds: 160);
  static const statusFadeDuration = Duration(milliseconds: 200);
}
