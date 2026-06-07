import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/discovery_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/peer_device_tile.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';

/// Discovery screen — main screen of the application.
///
/// Shows:
///   - Scanning status banner.
///   - Deduplicated, signal-sorted list of discovered peers.
///   - Empty state when no peers are found.
///   - Error state if discovery fails.
///
/// Navigates to [PairingScreen] when a peer is selected.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    // Start discovery when the screen is first shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Nearby Devices',
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => context.goNamed(AppRouteNames.settings),
        ),
      ],
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          // ── Scanning banner ──────────────────────────────────────
          _ScanningBanner(isScanning: state.isScanning),

          // ── Error state ──────────────────────────────────────────
          if (state.hasError)
            _ErrorBanner(error: state.error!)
          // ── Peer list ────────────────────────────────────────────
          else if (state.hasPeers)
            Expanded(
              child: ListView.separated(
                padding: AppTheme.pagePadding,
                itemCount: state.sortedPeers.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTheme.spacingXs),
                itemBuilder: (context, i) {
                  final peer = state.sortedPeers[i];
                  return PeerDeviceTile(
                    peer: peer,
                    onTap: () => context.goNamed(
                      AppRouteNames.pairing,
                      pathParameters: {'peerId': peer.id},
                    ),
                  );
                },
              ),
            )
          // ── Empty state ──────────────────────────────────────────
          else
            Expanded(
              child: _EmptyState(isScanning: state.isScanning),
            ),
        ],
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
                  'Scanning for devices…',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: AppTheme.pagePadding,
      child: Card(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.warning_rounded, color: cs.onErrorContainer),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  error,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isScanning});
  final bool isScanning;

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
              isScanning
                  ? Icons.bluetooth_searching_rounded
                  : Icons.bluetooth_disabled_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              isScanning ? 'Looking for devices…' : 'No devices found',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'Make sure the other device has Ether Synapse open\n'
              'and is within Bluetooth range.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
