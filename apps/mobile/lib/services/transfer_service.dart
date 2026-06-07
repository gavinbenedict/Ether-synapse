import '../shared/models/transfer_job.dart';

/// Contract for file transfer operations.
///
/// All file I/O, framing, encryption, and QUIC stream management are performed
/// by the Rust core. Flutter calls this service with a file path and receives
/// progress events in return.
///
/// DO NOT add file I/O here.
/// DO NOT add encryption here.
/// DO NOT add network I/O here.
abstract interface class TransferService {
  /// Send a file at [filePath] to the peer in the current active session.
  ///
  /// Returns a [TransferJob] representing the in-progress transfer.
  /// Progress updates are emitted via [progressStream].
  ///
  /// Throws [TransferException] if no active session exists or the file
  /// cannot be opened.
  Future<TransferJob> sendFile(String filePath);

  /// Send multiple files as a batch.
  ///
  /// Returns a job for each file. Files are transferred on concurrent
  /// QUIC streams up to the session stream limit.
  Future<List<TransferJob>> sendBatch(List<String> filePaths);

  /// Cancel the transfer identified by [jobId].
  Future<void> cancelTransfer(String jobId);

  /// Emits [TransferJob] snapshots as progress changes for all active jobs.
  Stream<TransferJob> get progressStream;

  /// The list of all jobs (active and completed) in this session.
  List<TransferJob> get jobs;
}

/// Thrown when a [TransferService] operation fails.
final class TransferException implements Exception {
  const TransferException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'TransferException: $message${cause != null ? ' ($cause)' : ''}';
}
