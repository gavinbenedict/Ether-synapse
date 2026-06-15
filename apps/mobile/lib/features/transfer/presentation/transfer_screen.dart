import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/transfer_provider.dart';
import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';
import '../../../shared/utils/file_utils.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';

/// Transfer screen — shown after pairing completes.
///
/// Displays:
///   - Send file FAB
///   - Incoming offer cards (accept / reject)
///   - Active transfer progress cards
///   - Completed transfer history
///   - Empty state when idle
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({
    super.key, 
    required this.peerId,
    required this.hostIp,
    required this.isHost,
  });

  final String peerId;
  final String hostIp;
  final bool isHost;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(transferProvider.notifier).startReceiver(widget.hostIp);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider);
    final notifier = ref.read(transferProvider.notifier);

    return AppScaffold(
      title: 'Transfer',
      body: state.hasJobs
          ? _JobList(
              jobs: state.jobs,
              onAccept: notifier.acceptOffer,
              onReject: notifier.rejectOffer,
              onCancel: notifier.cancelTransfer,
            )
          : const _EmptyState(),
      floatingActionButton: widget.isHost ? null : FloatingActionButton.extended(
        onPressed: state.isPickingFile ? null : () => notifier.pickAndSendFile(widget.hostIp),
        icon: state.isPickingFile
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.attach_file_rounded),
        label: Text(state.isPickingFile ? 'Picking…' : 'Send File'),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _JobList extends StatelessWidget {
  const _JobList({
    required this.jobs,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
  });

  final List<TransferJob> jobs;
  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(String) onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: jobs.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTheme.spacingXs),
      itemBuilder: (context, i) {
        final job = jobs[i];
        return switch (job.status) {
          TransferStatus.offering => _OfferCard(
              job: job,
              onAccept: () => onAccept(job.id),
              onReject: () => onReject(job.id),
            ),
          TransferStatus.transferring => _ProgressCard(
              job: job,
              onCancel: () => onCancel(job.id),
            ),
          _ => _CompletedCard(job: job),
        };
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.job,
    required this.onAccept,
    required this.onReject,
  });

  final TransferJob job;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_rounded, color: cs.primary, size: 20),
                const SizedBox(width: AppTheme.spacingXs),
                Text('Incoming File', style: tt.labelMedium?.copyWith(color: cs.primary)),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(job.fileName,
                style: tt.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(FileSizeUtils.format(job.fileSize),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
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

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.job, required this.onCancel});

  final TransferJob job;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.fileName,
                          style: tt.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${FileSizeUtils.format(job.bytesTransferred)} '
                        'of ${FileSizeUtils.format(job.fileSize)}',
                        style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${job.progressPercent}%',
                  style: tt.labelLarge?.copyWith(color: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              child: LinearProgressIndicator(
                value: job.progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.job});

  final TransferJob job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSuccess = job.status == TransferStatus.complete;

    return Card(
      child: ListTile(
        leading: Icon(
          isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
          color: isSuccess ? cs.primary : cs.error,
        ),
        title: Text(job.fileName,
            style: tt.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isSuccess
              ? FileSizeUtils.format(job.fileSize)
              : job.errorMessage ?? 'Transfer failed',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: isSuccess
            ? Text(job.status.label,
                style: tt.labelSmall?.copyWith(color: cs.primary))
            : Text(job.status.label,
                style: tt.labelSmall?.copyWith(color: cs.error)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.upload_file_rounded,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: AppTheme.spacingMd),
          Text('Ready to transfer',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppTheme.spacingXs),
          Text('Tap the button below to send a file.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
