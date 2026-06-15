import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/transfer_state.dart';
import '../data/tcp_transfer_service.dart';

/// Riverpod [StateNotifier] for the transfer screen.
///
/// Responsibilities:
///   - Invoke file picker and forward selected paths to the repository.
///   - Listen to the repository progress stream and merge job snapshots.
///   - Expose accept/reject actions for incoming offers.
///   - Surface aggregate progress to the UI.
class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier() : super(const TransferState());
  
  final _tcpService = TcpTransferService();
  bool _isReceiver = false;

  void _listenToProgress() {
    _tcpService.progressStream.listen((job) {
      if (mounted) {
        state = state.withUpdatedJob(job);
      }
    });
  }

  /// Start the TCP receiver server
  Future<void> startReceiver(String host) async {
    if (_isReceiver) return;
    _isReceiver = true;
    _listenToProgress();
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/EtherSynapse';
      final dirFile = Directory(savePath);
      if (!await dirFile.exists()) {
        await dirFile.create(recursive: true);
      }
      
      await _tcpService.startServer('0.0.0.0', 8080, savePath);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: 'Failed to start receiver: $e');
      }
    }
  }

  /// Open the platform file picker and send the selected file.
  Future<void> pickAndSendFile(String host) async {
    state = state.copyWith(isPickingFile: true);
    
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        state = state.copyWith(isPickingFile: false);
        return;
      }
      
      state = state.copyWith(isPickingFile: false);
      _listenToProgress();
      
      final file = File(result.files.single.path!);
      await _tcpService.sendFile(host, 8080, file);
      
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isPickingFile: false,
          error: 'Send failed: $e',
        );
      }
    }
  }

  /// Open the platform file picker and send multiple files as a batch.
  Future<void> pickAndSendBatch() async {
    // Currently unsupported by TCP protocol
    state = state.copyWith(isPickingFile: false);
  }

  /// Cancel an in-progress transfer.
  Future<void> cancelTransfer(String jobId) async {
    // TCP abort not implemented yet
  }
  
  /// Accept an incoming file offer from the peer.
  Future<void> acceptOffer(String jobId) async {
    // TCP auto-accepts currently
  }

  /// Reject an incoming file offer from the peer.
  Future<void> rejectOffer(String jobId) async {
    // TCP auto-accepts currently
  }
  
  @override
  void dispose() {
    if (_isReceiver) {
      _tcpService.stopServer();
    }
    super.dispose();
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
