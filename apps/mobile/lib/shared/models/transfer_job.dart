import 'package:flutter/foundation.dart';

import 'transfer_status.dart';

/// Represents a single in-progress or completed file transfer.
///
/// This is a pure value object updated by the Rust core via bridge events.
/// Flutter never mutates this directly — it receives updated snapshots
/// through the [TransferService.progressStream].
@immutable
final class TransferJob {
  const TransferJob({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.status,
    this.bytesTransferred = 0,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });

  /// Unique identifier for this transfer job.
  /// Assigned by the Rust core; opaque to Flutter.
  final String id;

  /// Display name of the file being transferred.
  final String fileName;

  /// Total file size in bytes.
  final int fileSize;

  /// Current transfer status.
  final TransferStatus status;

  /// Bytes transferred so far.
  final int bytesTransferred;

  /// Error description if [status] is [TransferStatus.error].
  /// Must not contain cryptographic material.
  final String? errorMessage;

  /// Wall-clock time when the transfer started.
  final DateTime? startedAt;

  /// Wall-clock time when the transfer completed (success or failure).
  final DateTime? completedAt;

  // ── Convenience ───────────────────────────────────────────────────

  /// Transfer progress as a value 0.0–1.0.
  double get progress {
    if (fileSize <= 0) return 0;
    return (bytesTransferred / fileSize).clamp(0.0, 1.0);
  }

  /// Transfer progress as a percentage 0–100.
  int get progressPercent => (progress * 100).round();

  /// Whether the transfer is in a terminal state (complete or error).
  bool get isTerminal =>
      status == TransferStatus.complete || status == TransferStatus.error;

  /// Transfer duration, or `null` if not yet started or not yet completed.
  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  TransferJob copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    TransferStatus? status,
    int? bytesTransferred,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TransferJob(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferJob && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TransferJob(id: $id, file: $fileName, status: $status, '
      'progress: $progressPercent%)';
}
