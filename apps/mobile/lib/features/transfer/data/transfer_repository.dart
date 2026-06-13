import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';

/// Data layer for the transfer feature.
///
/// Owns the interface between the transfer Riverpod provider and the
/// Rust core (via the flutter_rust_bridge event stream).
///
/// DO NOT add file I/O here.
/// DO NOT add encryption here.
/// DO NOT call flutter_rust_bridge directly here.
abstract interface class TransferRepository {
  /// Request the Rust core to send the file at [filePath].
  ///
  /// [filePath] is an absolute path obtained from file_picker.
  /// The path is forwarded to Rust as-is — Flutter does not open the file.
  ///
  /// Returns a [TransferJob] with its initial state.
  Future<TransferJob> sendFile(String filePath);

  /// Request the Rust core to send multiple files as a batch.
  Future<List<TransferJob>> sendBatch(List<String> filePaths);

  /// Cancel the transfer identified by [jobId].
  Future<void> cancelTransfer(String jobId);

  /// Accept an incoming file offer (receiver side).
  Future<void> acceptOffer(String jobId);

  /// Reject an incoming file offer (receiver side).
  Future<void> rejectOffer(String jobId);

  /// Stream of [TransferJob] snapshots emitted by the Rust core.
  ///
  /// Each emission is a complete, updated snapshot of a single job.
  Stream<TransferJob> get progressStream;
}
