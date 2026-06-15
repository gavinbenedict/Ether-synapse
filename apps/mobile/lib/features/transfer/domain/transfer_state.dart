import 'package:flutter/foundation.dart';

import '../../../shared/models/transfer_job.dart';

/// Domain state for the transfer feature.
@immutable
final class TransferState {
  const TransferState({
    this.jobs = const [],
    this.history = const [],
    this.isPickingFile = false,
    this.error,
  });

  /// Active in-session transfer jobs (in-flight or just completed).
  final List<TransferJob> jobs;

  /// Persisted transfer history (loaded from SharedPreferences on init).
  final List<TransferJob> history;

  /// `true` while the file picker sheet is open.
  final bool isPickingFile;

  /// Non-null if an unrecoverable error occurred outside a specific job.
  final String? error;

  // ── Convenience ───────────────────────────────────────────────────

  List<TransferJob> get activeJobs =>
      jobs.where((j) => j.status.isActive).toList();

  List<TransferJob> get completedJobs =>
      jobs.where((j) => j.isTerminal).toList();

  bool get hasActiveTransfer => activeJobs.isNotEmpty;
  bool get hasJobs => jobs.isNotEmpty;
  bool get hasHistory => history.isNotEmpty;
  bool get hasError => error != null;

  double get overallProgress {
    if (activeJobs.isEmpty) return 0;
    final total = activeJobs.fold<double>(0, (sum, j) => sum + j.progress);
    return total / activeJobs.length;
  }

  TransferState copyWith({
    List<TransferJob>? jobs,
    List<TransferJob>? history,
    bool? isPickingFile,
    String? error,
    bool clearError = false,
  }) {
    return TransferState(
      jobs: jobs ?? this.jobs,
      history: history ?? this.history,
      isPickingFile: isPickingFile ?? this.isPickingFile,
      error: clearError ? null : (error ?? this.error),
    );
  }

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
          listEquals(other.history, history) &&
          other.isPickingFile == isPickingFile &&
          other.error == error;

  @override
  int get hashCode => Object.hash(jobs, history, isPickingFile, error);
}
