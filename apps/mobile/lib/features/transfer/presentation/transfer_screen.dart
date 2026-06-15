import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';

import '../presentation/transfer_provider.dart';
import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';
import '../../../shared/utils/file_utils.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_theme.dart';

/// Transfer screen — shown after pairing completes on BOTH devices.
///
/// Receiver (isHost: true):
///   - Starts TCP server immediately on entry.
///   - Shows incoming progress card.
///   - On completion: shows "File Received" completion card.
///
/// Sender (isHost: false):
///   - Shows Send File FAB.
///   - On selection: streams the file, shows progress.
///   - On completion: shows "Transfer Complete" completion card.
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
    debugPrint('[TCP ${widget.isHost ? "SERVER" : "CLIENT"}] TransferScreen entered');
    debugPrint('[TCP ${widget.isHost ? "SERVER" : "CLIENT"}] peerId=${widget.peerId}');
    debugPrint('[TCP ${widget.isHost ? "SERVER" : "CLIENT"}] hostIp=${widget.hostIp}');
    debugPrint('[TCP ${widget.isHost ? "SERVER" : "CLIENT"}] isHost=${widget.isHost}');

    if (widget.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('[TCP SERVER] startReceiver invoked');
        ref.read(transferProvider(widget.peerId).notifier).startReceiver();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferProvider(widget.peerId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // The most recent completed job in this session (if any).
    final latestCompleted = state.completedJobs.isNotEmpty
        ? state.completedJobs.last
        : null;

    // All jobs: active + completed in session.
    final sessionJobs = state.jobs;
    // History from prior sessions.
    final history = state.history;

    return PopScope(
      canPop: true,
      child: AppScaffold(
        title: widget.isHost ? 'Receiving' : 'Sending',
        leading: BackButton(onPressed: () => context.pop()),
        floatingActionButton: (!widget.isHost && !state.hasActiveTransfer)
            ? _SendFab(
                onPressed: () => ref
                    .read(transferProvider(widget.peerId).notifier)
                    .pickAndSendFile(widget.hostIp),
                isPickingFile: state.isPickingFile,
              )
            : null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Error banner ──────────────────────────────────────
              if (state.hasError) ...[
                _ErrorBanner(
                  error: state.error!,
                  onDismiss: () => ref
                      .read(transferProvider(widget.peerId).notifier)
                      .dismissError(),
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],

              // ── Session jobs (active + completed) ─────────────────
              if (sessionJobs.isNotEmpty) ...[
                Text(
                  widget.isHost ? 'Incoming Transfer' : 'Current Transfer',
                  style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ...sessionJobs.map((job) => _TransferCard(
                      job: job,
                      isHost: widget.isHost,
                    )),
                const SizedBox(height: AppTheme.spacingMd),
              ],

              // ── Completion card (latest completed job in session) ──
              if (latestCompleted != null &&
                  latestCompleted.status == TransferStatus.complete) ...[
                _CompletionCard(
                  job: latestCompleted,
                  isHost: widget.isHost,
                  onSendAnother: widget.isHost
                      ? null
                      : () => ref
                          .read(transferProvider(widget.peerId).notifier)
                          .pickAndSendFile(widget.hostIp),
                  onDone: () => context.pop(),
                ),
                const SizedBox(height: AppTheme.spacingMd),
              ],

              // ── Waiting state (receiver, no jobs yet) ─────────────
              if (widget.isHost && sessionJobs.isEmpty)
                _WaitingCard(cs: cs, tt: tt),

              // ── Transfer history (persisted from prior sessions) ───
              if (history.isNotEmpty) ...[
                const Divider(height: AppTheme.spacingXxl),
                Text(
                  'Transfer History',
                  style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.spacingSm),
                ...history.map((job) => _HistoryCard(job: job)),
              ],

              const SizedBox(height: 80), // FAB clearance
            ],
          ),
        ),
      ),
    );
  }
}

// ── Send FAB ──────────────────────────────────────────────────────────────────

class _SendFab extends StatelessWidget {
  const _SendFab({required this.onPressed, required this.isPickingFile});
  final VoidCallback onPressed;
  final bool isPickingFile;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: isPickingFile ? null : onPressed,
      icon: isPickingFile
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file_rounded),
      label: Text(isPickingFile ? 'Picking…' : 'Send File'),
    );
  }
}

// ── Waiting card (receiver, no transfers yet) ─────────────────────────────────

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          children: [
            Icon(Icons.download_rounded, size: 56, color: cs.primary),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Waiting for Sender',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'TCP server is running. The sender can now select a file to transfer.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active / progress transfer card ──────────────────────────────────────────

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.job, required this.isHost});
  final TransferJob job;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDone = job.status == TransferStatus.complete;
    final isFailed = job.status == TransferStatus.error;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileTypeIcon(mimeType: job.mimeType, size: 36),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.fileName,
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        FileSizeUtils.format(job.fileSize),
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isDone)
                  Icon(Icons.check_circle_rounded, color: cs.primary)
                else if (isFailed)
                  Icon(Icons.error_rounded, color: cs.error)
                else
                  Text(
                    '${job.progressPercent}%',
                    style: tt.labelSmall?.copyWith(color: cs.primary),
                  ),
              ],
            ),
            if (job.status == TransferStatus.transferring) ...[
              const SizedBox(height: AppTheme.spacingSm),
              LinearProgressIndicator(value: job.progress),
            ],
            if (isFailed && job.errorMessage != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                job.errorMessage!,
                style: tt.bodySmall?.copyWith(color: cs.error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Completion card ───────────────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.job,
    required this.isHost,
    required this.onDone,
    this.onSendAnother,
  });

  final TransferJob job;
  final bool isHost;
  final VoidCallback onDone;
  final VoidCallback? onSendAnother;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final dur = job.duration;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: cs.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  isHost ? '✓ File Received' : '✓ Transfer Complete',
                  style: tt.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // ── Thumbnail (images only) ───────────────────────────────────
            if (_isImage(job.mimeType) && job.thumbnailPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _LocalOrContentImage(
                  path: job.thumbnailPath!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            if (_isImage(job.mimeType) && job.thumbnailPath != null)
              const SizedBox(height: AppTheme.spacingMd),

            // ── Details table ──────────────────────────────────────
            _DetailRow(
              icon: Icons.insert_drive_file_rounded,
              label: 'File',
              value: job.fileName,
              cs: cs,
              tt: tt,
            ),
            if (isHost && job.peerName != null)
              _DetailRow(
                icon: Icons.person_rounded,
                label: 'From',
                value: job.peerName!,
                cs: cs,
                tt: tt,
              ),
            if (!isHost && job.peerName != null)
              _DetailRow(
                icon: Icons.person_rounded,
                label: 'Sent To',
                value: job.peerName!,
                cs: cs,
                tt: tt,
              ),
            _DetailRow(
              icon: Icons.data_usage_rounded,
              label: 'Size',
              value: FileSizeUtils.format(job.fileSize),
              cs: cs,
              tt: tt,
            ),
            if (dur != null)
              _DetailRow(
                icon: Icons.timer_rounded,
                label: 'Time',
                value: FileSizeUtils.formatDuration(dur),
                cs: cs,
                tt: tt,
              ),
            if (isHost && job.localPath != null)
              _DetailRow(
                icon: Icons.folder_rounded,
                label: 'Saved To',
                value: _friendlyPath(job.localPath!),
                cs: cs,
                tt: tt,
              ),

            const SizedBox(height: AppTheme.spacingMd),

            // ── Action buttons ─────────────────────────────────────
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: [
                if (isHost && job.localPath != null) ...[
                  FilledButton.icon(
                    onPressed: () => _openFile(context, job.localPath!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open File'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.onPrimaryContainer,
                      foregroundColor: cs.primaryContainer,
                    ),
                  ),
                ],
                if (!isHost && onSendAnother != null)
                  FilledButton.icon(
                    onPressed: onSendAnother,
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: const Text('Send Another'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.onPrimaryContainer,
                      foregroundColor: cs.primaryContainer,
                    ),
                  ),
                OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.onPrimaryContainer),
                    foregroundColor: cs.onPrimaryContainer,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static bool _isImage(String? mime) =>
      mime?.startsWith('image/') == true;

  static String _friendlyPath(String path) {
    // Show only the last two segments for readability
    final parts = path.replaceAll('\\', '/').split('/');
    if (parts.length >= 2) return '…/${parts[parts.length - 2]}/${parts.last}';
    return path;
  }

  Future<void> _openFile(BuildContext context, String path) async {
    debugPrint('[OPEN FILE] path=$path');
    try {
      final result = await OpenFile.open(path);
      if (result.type == ResultType.done) {
        debugPrint('[OPEN FILE] success');
      } else {
        debugPrint('[OPEN FILE] failed — type: ${result.type}, msg: ${result.message}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open: ${result.message}')),
          );
        }
      }
    } catch (e) {
      debugPrint('[OPEN FILE] error: $e');
    }
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.job});
  final TransferJob job;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSent = job.isSent;
    final isFailed = job.status == TransferStatus.error;
    final ts = job.completedAt;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingXs),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: job.hasLocalFile ? () => _openFile(context, job.localPath!) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // Thumbnail or file-type icon
              _ThumbnailOrIcon(job: job, size: 48),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.fileName,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          isSent
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: isSent ? cs.primary : cs.secondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isSent ? 'Sent' : 'Received',
                          style: tt.labelSmall?.copyWith(
                            color: isSent ? cs.primary : cs.secondary,
                          ),
                        ),
                        Text(
                          '  •  ${FileSizeUtils.format(job.fileSize)}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (ts != null)
                      Text(
                        _formatTimestamp(ts),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isFailed)
                Icon(Icons.error_outline_rounded, color: cs.error, size: 18)
              else if (job.hasLocalFile)
                Icon(Icons.open_in_new_rounded, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _openFile(BuildContext context, String path) async {
    debugPrint('[OPEN FILE] path=$path');
    try {
      final result = await OpenFile.open(path);
      if (result.type == ResultType.done) {
        debugPrint('[OPEN FILE] success');
      } else {
        debugPrint('[OPEN FILE] failed — ${result.message}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open: ${result.message}')),
          );
        }
      }
    } catch (e) {
      debugPrint('[OPEN FILE] error: $e');
    }
  }
}

// ── Thumbnail or file type icon ───────────────────────────────────────────────

class _ThumbnailOrIcon extends StatelessWidget {
  const _ThumbnailOrIcon({required this.job, required this.size});
  final TransferJob job;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Image with a real thumbnail file or content URI.
    if (job.thumbnailPath != null && job.thumbnailPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _LocalOrContentImage(
          path: job.thumbnailPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fallback: _FileTypeIcon(mimeType: job.mimeType, size: size),
        ),
      );
    }

    return _FileTypeIcon(mimeType: job.mimeType, size: size);
  }
}

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({this.mimeType, required this.size});
  final String? mimeType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _iconFor(mimeType);
    final color = _colorFor(mimeType, cs);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }

  static IconData _iconFor(String? mime) {
    final cat = mime?.split('/').first ?? '';
    return switch (cat) {
      'image' => Icons.image_rounded,
      'video' => Icons.play_circle_rounded,
      'audio' => Icons.music_note_rounded,
      'application' => _appIcon(mime),
      _ => Icons.insert_drive_file_rounded,
    };
  }

  static IconData _appIcon(String? mime) {
    if (mime == null) return Icons.insert_drive_file_rounded;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mime.contains('zip') || mime.contains('rar') || mime.contains('tar')) {
      return Icons.folder_zip_rounded;
    }
    if (mime.contains('word') || mime.contains('doc')) return Icons.article_rounded;
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Icons.table_chart_rounded;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  static Color _colorFor(String? mime, ColorScheme cs) {
    final cat = mime?.split('/').first ?? '';
    return switch (cat) {
      'image' => cs.tertiary,
      'video' => cs.error,
      'audio' => cs.secondary,
      'application' => cs.primary,
      _ => cs.outline,
    };
  }
}

// ── Detail row helper ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: tt.bodySmall?.copyWith(
              color: cs.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: tt.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onDismiss});
  final String error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
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
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, color: cs.onErrorContainer),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Content-URI-safe image widget ────────────────────────────────────────
//
// Android 10+ MediaStore may return a content:// URI instead of a real
// file path.  Image.file(File('content://...')) throws a FileSystemException
// because dart:io cannot open a content URI.  This widget detects the form
// of [path] and delegates to the correct image provider:
//
//   content:// → Image.network  (flutter resolves content URIs via http)
//   file path  → Image.file     (dart:io FileImage)
//
// Both branches share the same [errorBuilder] / [fallback].

class _LocalOrContentImage extends StatelessWidget {
  const _LocalOrContentImage({
    required this.path,
    this.width,
    this.height,
    this.fit,
    this.fallback = const SizedBox.shrink(),
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// Widget to display when the image cannot be loaded.
  final Widget fallback;

  /// Returns true if [path] is an Android content URI.
  static bool _isContentUri(String path) =>
      path.startsWith('content://');

  @override
  Widget build(BuildContext context) {
    if (_isContentUri(path)) {
      // content:// URIs cannot be opened with dart:io File.
      // flutter's Image.network resolves Android content URIs correctly
      // when running on-device.
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    // Standard filesystem path.
    final file = File(path);
    if (!file.existsSync()) return fallback;

    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
