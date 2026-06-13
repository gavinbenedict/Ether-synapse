import 'package:flutter/foundation.dart';

import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';

/// Domain state for the transfer feature.
///
/// Immutable snapshot updated by [TransferNotifier] as bridge events arrive.
@immutable
final class TransferState {
  const TransferState({
    this.jobs = const [],
    this.isPickingFile = false,
    this.error,
  });

  /// All transfer jobs in the current session (active + completed).
  final List<TransferJob> jobs;

  /// `true` while the file picker sheet is open.
  final bool isPickingFile;

  /// Non-null if an unrecoverable error occurred outside a specific job.
  final String? error;

  // ── Convenience ───────────────────────────────────────────────────

  /// Jobs currently in-flight (offering or transferring).
  List<TransferJob> get activeJobs =>
      jobs.where((j) => j.status.isActive).toList();

  /// Jobs that have completed (success or failure).
  List<TransferJob> get completedJobs =>
      jobs.where((j) => j.isTerminal).toList();

  /// Whether any transfer is currently in progress.
  bool get hasActiveTransfer => activeJobs.isNotEmpty;

  bool get hasJobs => jobs.isNotEmpty;
  bool get hasError => error != null;

  /// Aggregate progress across all active jobs (0.0–1.0).
  double get overallProgress {
    if (activeJobs.isEmpty) return 0;
    final total = activeJobs.fold<double>(0, (sum, j) => sum + j.progress);
    return total / activeJobs.length;
  }

  TransferState copyWith({
    List<TransferJob>? jobs,
    bool? isPickingFile,
    String? error,
    bool clearError = false,
  }) {
    return TransferState(
      jobs: jobs ?? this.jobs,
      isPickingFile: isPickingFile ?? this.isPickingFile,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Returns [jobs] with [updated] merged in by job ID.
  TransferState withUpdatedJob(TransferJob updated) {
    final idx = jobs.indexWhere((j) => j.id == updated.id);
    final next = List<TransferJob>.of(jobs);
    if (idx == -1) {
      next.add(updated);
    } else {
      next[idx] = updated;
    }
    return copyWith(jobs: next);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransferState &&
          listEquals(other.jobs, jobs) &&
          other.isPickingFile == isPickingFile &&
          other.error == error;

  @override
  int get hashCode => Object.hash(jobs, isPickingFile, error);
}
