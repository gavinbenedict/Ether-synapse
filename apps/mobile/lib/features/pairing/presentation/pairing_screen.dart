import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/pairing_provider.dart';
import '../domain/pairing_state.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/routes.dart';
import '../../../services/pairing_service.dart';

/// Pairing screen — shown after the user selects a peer.
///
/// Displays:
///   - Connecting state (spinner)
///   - PIN display (6-digit, split for readability)
///   - Confirm / Reject actions
///   - Error state
///   - Success state → navigates to transfer
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, required this.peerId});

  final String peerId;

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  @override
  void initState() {
    super.initState();
    // TODO(impl): Resolve peer from discoveryProvider by peerId, then call
    // ref.read(pairingProvider.notifier).startPairing(peer);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pairingProvider);

    // Navigate to transfer when pairing completes successfully.
    ref.listen<PairingState>(pairingProvider, (_, next) {
      if (next.isPaired && next.endpointAddress != null) {
        context.goNamed(
          AppRouteNames.transfer,
          pathParameters: {'peerId': widget.peerId},
        );
      }
    });

    return AppScaffold(
      leading: BackButton(onPressed: () {
        ref.read(pairingProvider.notifier).cancel();
        context.pop();
      }),
      title: 'Pair Device',
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, PairingState state) {
    return switch (state.status) {
      PairingStatus.idle || PairingStatus.connecting => _ConnectingView(),
      PairingStatus.exchangingKeys => _ConnectingView(label: 'Exchanging keys…'),
      PairingStatus.awaitingConfirmation => _PinVerificationView(
          pin: state.formattedPin ?? '------',
          peerName: state.peer?.name ?? 'Device',
          onConfirm: () =>
              ref.read(pairingProvider.notifier).confirmPin(),
          onReject: () =>
              ref.read(pairingProvider.notifier).rejectPin(),
        ),
      PairingStatus.confirmed => _SuccessView(
          peerName: state.peer?.name ?? 'Device',
        ),
      PairingStatus.rejected => _RejectedView(
          onRetry: () => context.pop(),
        ),
      PairingStatus.failed => _ErrorView(
          message: state.error ?? 'Pairing failed.',
          onRetry: () => context.pop(),
        ),
    };
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({this.label = 'Connecting…'});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: AppTheme.spacingLg),
          Text(label, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _PinVerificationView extends StatelessWidget {
  const _PinVerificationView({
    required this.pin,
    required this.peerName,
    required this.onConfirm,
    required this.onReject,
  });

  final String pin;
  final String peerName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),

        // Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.verified_rounded,
              size: 36, color: cs.onSecondaryContainer),
        ),

        const SizedBox(height: AppTheme.spacingLg),

        Text('Verify Connection', style: tt.headlineSmall),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          'Confirm this code matches on $peerName',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppTheme.spacingXl),

        // PIN display
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingXl,
            vertical: AppTheme.spacingLg,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            pin,
            style: tt.displaySmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
          ),
        ),

        const Spacer(),

        // Actions
        FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Codes Match'),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        OutlinedButton.icon(
          onPressed: onReject,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Codes Don\'t Match'),
        ),
        const SizedBox(height: AppTheme.spacingLg),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.peerName});
  final String peerName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 72, color: cs.primary),
          const SizedBox(height: AppTheme.spacingMd),
          Text('Connected to $peerName', style: tt.titleLarge),
          const SizedBox(height: AppTheme.spacingXs),
          Text('Opening transfer…',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView({required this.onRetry});
  final VoidCallback onRetry;

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
            Icon(Icons.security_rounded, size: 64, color: cs.error),
            const SizedBox(height: AppTheme.spacingMd),
            Text('Pairing Rejected', style: tt.titleLarge),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'The verification codes did not match.\n'
              'Do not proceed — a man-in-the-middle attack may have been attempted.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton(onPressed: onRetry, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
            Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
            const SizedBox(height: AppTheme.spacingMd),
            Text('Pairing Failed', style: tt.titleLarge),
            const SizedBox(height: AppTheme.spacingXs),
            Text(message,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.spacingXl),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
