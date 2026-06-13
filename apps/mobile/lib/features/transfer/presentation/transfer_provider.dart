import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transfer_state.dart';
import '../../../shared/models/transfer_job.dart';

/// Riverpod [StateNotifier] for the transfer screen.
///
/// Responsibilities:
///   - Invoke file picker and forward selected paths to the repository.
///   - Listen to the repository progress stream and merge job snapshots.
///   - Expose accept/reject actions for incoming offers.
///   - Surface aggregate progress to the UI.
///
/// DO NOT add file I/O here.
/// DO NOT call flutter_rust_bridge directly here.
class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(const TransferState());

  // TODO(impl): Inject TransferRepository + file_picker via provider override.

  /// Open the platform file picker and send the selected file.
  Future<void> pickAndSendFile() async {
    state = state.copyWith(isPickingFile: true);
    // TODO(impl):
    //   final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    //   if (result == null || result.files.isEmpty) {
    //     state = state.copyWith(isPickingFile: false);
    //     return;
    //   }
    //   state = state.copyWith(isPickingFile: false);
    //   final job = await _repository.sendFile(result.files.single.path!);
    //   state = state.withUpdatedJob(job);
    state = state.copyWith(isPickingFile: false);
  }

  /// Open the platform file picker and send multiple files as a batch.
  Future<void> pickAndSendBatch() async {
    state = state.copyWith(isPickingFile: true);
    // TODO(impl): Similar to pickAndSendFile but with allowMultiple: true.
    state = state.copyWith(isPickingFile: false);
  }

  /// Accept an incoming file offer from the peer.
  Future<void> acceptOffer(String jobId) async {
    // TODO(impl): await _repository.acceptOffer(jobId);
  }

  /// Reject an incoming file offer from the peer.
  Future<void> rejectOffer(String jobId) async {
    // TODO(impl): await _repository.rejectOffer(jobId);
  }

  /// Cancel an in-progress transfer.
  Future<void> cancelTransfer(String jobId) async {
    // TODO(impl): await _repository.cancelTransfer(jobId);
  }

  /// Called by the progress stream listener with updated job snapshots.
  void _onJobUpdate(TransferJob job) {
    state = state.withUpdatedJob(job);
  }

  void _onError(Object error) {
    state = state.copyWith(error: error.toString());
  }
}

/// Provider for [TransferNotifier].
///
/// autoDispose: the transfer state is released when the transfer
/// screen is no longer in the navigation stack.
final transferProvider =
    StateNotifierProvider.autoDispose<TransferNotifier, TransferState>((ref) {
  return TransferNotifier();
});
