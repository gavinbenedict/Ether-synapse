import 'package:flutter/foundation.dart';
import 'transfer_status.dart';

/// Direction of a transfer from the perspective of this device.
enum TransferDirection {
  sent,
  received;

  String get label => switch (this) {
        TransferDirection.sent => 'Sent',
        TransferDirection.received => 'Received',
      };
}

/// Represents a single in-progress or completed file transfer.
@immutable
final class TransferJob {
  const TransferJob({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.status,
    required this.direction,
    this.bytesTransferred = 0,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.localPath,
    this.mimeType,
    this.thumbnailPath,
    this.peerName,
  });

  /// Unique identifier for this transfer job.
  final String id;

  /// Display name of the file being transferred.
  final String fileName;

  /// Total file size in bytes.
  final int fileSize;

  /// Current transfer status.
  final TransferStatus status;

  /// Whether this device is the sender or receiver.
  final TransferDirection direction;

  /// Bytes transferred so far.
  final int bytesTransferred;

  /// Error description if [status] is [TransferStatus.error].
  final String? errorMessage;

  /// Wall-clock time when the transfer started.
  final DateTime? startedAt;

  /// Wall-clock time when the transfer completed (success or failure).
  final DateTime? completedAt;

  /// Absolute path to the saved file on this device (non-null on completion).
  final String? localPath;

  /// MIME type detected from file extension (e.g. "image/jpeg").
  final String? mimeType;

  /// Path to a generated thumbnail (images/videos only; null for other types).
  final String? thumbnailPath;

  /// Display name of the remote peer.
  final String? peerName;

  // ── Convenience ───────────────────────────────────────────────────

  double get progress {
    if (fileSize <= 0) return 0;
    return (bytesTransferred / fileSize).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  bool get isTerminal =>
      status == TransferStatus.complete || status == TransferStatus.error;

  bool get isSent => direction == TransferDirection.sent;
  bool get isReceived => direction == TransferDirection.received;

  Duration? get duration {
    if (startedAt == null || completedAt == null) return null;
    return completedAt!.difference(startedAt!);
  }

  /// Whether this job has a displayable file on disk.
  bool get hasLocalFile => localPath != null && localPath!.isNotEmpty;

  TransferJob copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    TransferStatus? status,
    TransferDirection? direction,
    int? bytesTransferred,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    String? localPath,
    String? mimeType,
    String? thumbnailPath,
    String? peerName,
  }) {
    return TransferJob(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      direction: direction ?? this.direction,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      peerName: peerName ?? this.peerName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'status': status.name,
        'direction': direction.name,
        'bytesTransferred': bytesTransferred,
        'errorMessage': errorMessage,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'localPath': localPath,
        'mimeType': mimeType,
        'thumbnailPath': thumbnailPath,
        'peerName': peerName,
      };

  factory TransferJob.fromJson(Map<String, dynamic> json) => TransferJob(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        status: TransferStatus.values.byName(
          json['status'] as String? ?? 'complete',
        ),
        direction: TransferDirection.values.byName(
          json['direction'] as String? ?? 'received',
        ),
        bytesTransferred: json['bytesTransferred'] as int? ?? 0,
        errorMessage: json['errorMessage'] as String?,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        localPath: json['localPath'] as String?,
        mimeType: json['mimeType'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        peerName: json['peerName'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferJob && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TransferJob(id: $id, file: $fileName, status: $status, '
      'progress: $progressPercent%, dir: ${direction.name})';
}
