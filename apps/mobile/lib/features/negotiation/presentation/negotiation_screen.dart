import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'negotiation_provider.dart';
import '../domain/negotiation_state.dart';
import '../../../shared/models/device_capabilities.dart';
import '../../../shared/models/transport_plan.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../services/system_settings_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/routes.dart';

/// Negotiation screen — shown when a sender taps a discovered receiver.
///
/// Phases displayed:
///   1. detectingLocal  → spinner + "Detecting capabilities…"
///   2. exchangingCapabilities → spinner + "Exchanging with remote…"
///   3. complete → capability cards + transport recommendation
///   4. failed → error card with retry
///
/// No file transfer happens here. This screen only selects the transport.
class NegotiationScreen extends ConsumerStatefulWidget {
  const NegotiationScreen({super.key, required this.peerId});

  final String peerId;

  @override
  ConsumerState<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends ConsumerState<NegotiationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(negotiationProvider(widget.peerId).notifier).negotiate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(negotiationProvider(widget.peerId));

    return AppScaffold(
      title: 'Connecting…',
      leading: BackButton(onPressed: () => context.pop()),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (state.phase) {
          NegotiationPhase.detectingLocal =>
            _PhaseCard(key: const ValueKey('detecting'), state: state),
          NegotiationPhase.exchangingCapabilities =>
            _PhaseCard(key: const ValueKey('exchanging'), state: state),
          NegotiationPhase.complete =>
            _CompleteView(key: const ValueKey('complete'), state: state, peerId: widget.peerId),
          NegotiationPhase.failed =>
            _FailedView(
              key: const ValueKey('failed'),
              state: state,
              onRetry: () => ref
                  .read(negotiationProvider(widget.peerId).notifier)
                  .negotiate(),
            ),
        },
      ),
    );
  }
}

// ── Spinner phase card ────────────────────────────────────────────────────────

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({super.key, required this.state});
  final NegotiationState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final label = state.phase == NegotiationPhase.detectingLocal
        ? 'Detecting capabilities…'
        : 'Exchanging with remote device…';

    final subtitle = state.phase == NegotiationPhase.detectingLocal
        ? 'Checking WiFi, hotspot, and transport support on this device.'
        : 'Determining the best way to transfer files.';

    return Center(
      child: Padding(
        padding: AppTheme.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: AppTheme.spacingLg),
            Text(
              label,
              style: tt.titleMedium?.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            // Show local capabilities as they are detected.
            if (state.localCapabilities != null) ...[
              const SizedBox(height: AppTheme.spacingXxl),
              _CapabilityCard(
                title: 'This Device',
                caps: state.localCapabilities!,
                cs: cs,
                tt: tt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Complete view ─────────────────────────────────────────────────────────────

class _CompleteView extends StatelessWidget {
  const _CompleteView({super.key, required this.state, required this.peerId});
  final NegotiationState state;
  final String peerId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final plan = state.transportPlan!;

    return SingleChildScrollView(
      padding: AppTheme.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────
          Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                children: [
                  Icon(
                    _transportIcon(plan.type),
                    size: 40,
                    color: cs.onPrimaryContainer,
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'Transfer via ${plan.type.label}',
                    style: tt.titleLarge?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingXs),
                  Text(
                    plan.reason,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Host / joiner info ─────────────────────────────────
          _HostCard(plan: plan, cs: cs, tt: tt),

          const SizedBox(height: AppTheme.spacingMd),

          // ── Capability cards ───────────────────────────────────
          if (state.localCapabilities != null)
            _CapabilityCard(
              title: 'This Device',
              caps: state.localCapabilities!,
              cs: cs,
              tt: tt,
            ),

          if (state.remoteCapabilities != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            _CapabilityCard(
              title: 'Remote Device',
              caps: state.remoteCapabilities!,
              cs: cs,
              tt: tt,
            ),
          ],

          const SizedBox(height: AppTheme.spacingMd),

          // ── User action (hotspot, WiFi Direct, etc.) ───────────
          if (plan.requiresUserAction) ...[
            _UserActionCard(plan: plan, cs: cs, tt: tt),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          // ── Proceed button (disabled until transport ready) ────
          if (!plan.requiresUserAction)
            FilledButton.icon(
              onPressed: () {
                // The receiver is always the TCP server host.
                // plan.hostDevice is remote (receiver); its localIpAddress
                // is the LAN IP the sender must connect to.
                final hostIp = plan.hostDevice.localIpAddress ?? '';

                debugPrint('[TCP CLIENT] Sender proceeding to transfer');
                debugPrint('[TCP CLIENT] peerId: $peerId');
                debugPrint('[TCP CLIENT] hostIp: $hostIp');
                debugPrint('[TCP CLIENT] isHost: false');

                if (hostIp.isEmpty) {
                  debugPrint(
                    '[TCP CLIENT] ERROR: hostIp is empty — '
                    'receiver IP was not exchanged in capabilities',
                  );
                  return;
                }

                // pushNamed keeps the route stack intact so Back returns
                // to NegotiationScreen → SendScreen → Home.
                context.pushNamed(
                  AppRouteNames.transfer,
                  pathParameters: {'peerId': peerId},
                  queryParameters: {
                    'hostIp': hostIp,
                    'isHost': 'false',
                  },
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Proceed to Transfer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),

          const SizedBox(height: AppTheme.spacingXxl),
        ],
      ),
    );
  }

  IconData _transportIcon(TransportType type) => switch (type) {
        TransportType.localWifi => Icons.wifi_rounded,
        TransportType.wifiDirect => Icons.wifi_tethering_rounded,
        TransportType.hotspot => Icons.wifi_tethering_rounded,
      };
}

// ── Failed view ───────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  const _FailedView({
    super.key,
    required this.state,
    required this.onRetry,
  });
  final NegotiationState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
                Icon(Icons.error_outline_rounded,
                    size: 48, color: cs.onErrorContainer),
                const SizedBox(height: AppTheme.spacingMd),
                Text(
                  'Negotiation Failed',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                if (state.error != null)
                  Text(
                    state.error!,
                    style:
                        tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: AppTheme.spacingLg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
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

// ── Shared sub-widgets ────────────────────────────────────────────────────────

/// Shows device capabilities in a compact card.
class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.title,
    required this.caps,
    required this.cs,
    required this.tt,
  });

  final String title;
  final DeviceCapabilities caps;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: tt.titleSmall?.copyWith(color: cs.primary)),
              ],
            ),
            const Divider(height: AppTheme.spacingLg),
            _CapRow(label: 'Name', value: caps.displayName, cs: cs, tt: tt),
            _CapRow(label: 'Model', value: caps.deviceName, cs: cs, tt: tt),
            _CapRow(
                label: 'App version',
                value: caps.appVersion,
                cs: cs,
                tt: tt),
            _CapRow(
                label: 'Android SDK',
                value: caps.androidSdkVersion > 0
                    ? '${caps.androidSdkVersion}'
                    : 'Unknown',
                cs: cs,
                tt: tt),
            _CapRow(
                label: 'WiFi',
                value: caps.wifiStandardLabel,
                cs: cs,
                tt: tt),
            _CapBoolRow(
                label: 'Local WiFi',
                value: caps.supportsLocalWifi,
                cs: cs,
                tt: tt),
            _CapBoolRow(
                label: 'WiFi Direct',
                value: caps.supportsWifiDirect,
                cs: cs,
                tt: tt),
            _CapBoolRow(
                label: 'Hotspot',
                value: caps.supportsHotspot,
                cs: cs,
                tt: tt),
          ],
        ),
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          Text(value,
              style: tt.bodySmall?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _CapBoolRow extends StatelessWidget {
  const _CapBoolRow({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });
  final String label;
  final bool value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          Icon(
            value ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: value ? cs.primary : cs.outlineVariant,
          ),
        ],
      ),
    );
  }
}

/// Shows who is the recommended host and why.
class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.plan,
    required this.cs,
    required this.tt,
  });
  final TransportPlan plan;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, size: 16, color: cs.tertiary),
                const SizedBox(width: 6),
                Text('Recommended Host',
                    style:
                        tt.titleSmall?.copyWith(color: cs.tertiary)),
              ],
            ),
            const Divider(height: AppTheme.spacingLg),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(Icons.phone_android_rounded,
                      size: 22, color: cs.onTertiaryContainer),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.hostDevice.displayName,
                        style: tt.titleSmall,
                      ),
                      Text(
                        '${plan.hostDevice.deviceName} • ${plan.hostDevice.wifiStandardLabel}',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// User action card — shown when the transport requires manual setup
/// (e.g. enabling a hotspot).
class _UserActionCard extends StatelessWidget {
  const _UserActionCard({
    required this.plan,
    required this.cs,
    required this.tt,
  });
  final TransportPlan plan;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cs.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 18, color: cs.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Action Required',
                  style: tt.titleSmall
                      ?.copyWith(color: cs.onSecondaryContainer),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
            if (plan.userActionDescription != null)
              Text(
                plan.userActionDescription!,
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSecondaryContainer),
              ),
            const SizedBox(height: AppTheme.spacingMd),
            FilledButton.icon(
              onPressed: plan.settingsAction != null
                  ? () => SystemSettingsService.open(plan.settingsAction!)
                  : null,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(plan.userActionLabel ?? 'Open Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.onSecondaryContainer,
                foregroundColor: cs.secondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
