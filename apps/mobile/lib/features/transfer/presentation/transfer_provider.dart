import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../domain/transfer_state.dart';
import '../data/tcp_transfer_service.dart';
import '../../../shared/models/transfer_job.dart';
import '../../../shared/services/transfer_history_service.dart';

/// Riverpod [StateNotifier] for the transfer screen.
///
/// Responsibilities:
///   - Receiver: starts TCP server immediately on screen entry.
///   - Sender: invokes file picker then streams file to the receiver.
///   - Listens to TCP service progress stream and merges job snapshots.
///   - Persists completed jobs to [TransferHistoryService].
///   - Loads persisted history on construction.
class TransferNotifier extends StateNotifier<TransferState> {
  TransferNotifier({this.peerName = 'Unknown'})
      : super(const TransferState()) {
    _init();
  }

  final String peerName;
  final _tcpService = TcpTransferService();
  StreamSubscription<TransferJob>? _progressSub;
  bool _isReceiver = false;
  bool _progressListening = false;

  Future<void> _init() async {
    // Load persisted history on startup.
    final history = await TransferHistoryService.load();
    if (mounted && history.isNotEmpty) {
      state = state.copyWith(history: history);
    }
  }

  // ── Progress listener ─────────────────────────────────────────────

  void _listenToProgress() {
    if (_progressListening) return;
    _progressListening = true;
    _progressSub = _tcpService.progressStream.listen((job) {
      if (!mounted) return;
      state = state.withUpdatedJob(job);
      // Persist terminal jobs to history.
      if (job.isTerminal) {
        TransferHistoryService.append(job);
      }
    });
  }

  // ── Receiver side ─────────────────────────────────────────────────

  /// Start the TCP receiver server.
  ///
  /// Must be called as soon as the receiver navigates to TransferScreen.
  Future<void> startReceiver() async {
    if (_isReceiver) return;
    _isReceiver = true;
    _listenToProgress();

    debugPrint('[TCP SERVER] startReceiver — peerName: $peerName');

    try {
      await _tcpService.startServer(peerName: peerName);
    } catch (e) {
      debugPrint('[TCP SERVER] startReceiver failed: $e');
      if (mounted) {
        state = state.copyWith(error: 'Failed to start receiver: $e');
      }
    }
  }

  // ── Sender side ───────────────────────────────────────────────────

  /// Open the platform file picker and send the selected file to [hostIp].
  Future<void> pickAndSendFile(String hostIp) async {
    if (state.isPickingFile) return;

    // Guard: block if the TCP service is already sending.
    if (_tcpService.isSending) {
      if (mounted) {
        state = state.copyWith(
          error: 'A transfer is already in progress. Wait for it to complete.',
        );
      }
      return;
    }

    state = state.copyWith(isPickingFile: true);

    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false);
      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        state = state.copyWith(isPickingFile: false);
        return;
      }

      state = state.copyWith(isPickingFile: false);
      _listenToProgress();

      final file = File(result.files.single.path!);
      debugPrint('[TCP CLIENT] File selected: ${file.path}');
      await _tcpService.sendFile(hostIp, file, peerName: peerName);
    } on StateError catch (e) {
      // Concurrent send attempted — show non-fatal message.
      debugPrint('[TCP CLIENT] Concurrent send blocked: $e');
      if (mounted) {
        state = state.copyWith(
          isPickingFile: false,
          error: 'Another transfer is already running.',
        );
      }
    } catch (e) {
      debugPrint('[TCP CLIENT] pickAndSendFile error: $e');
      if (mounted) {
        state = state.copyWith(
          isPickingFile: false,
          error: 'Send failed: $e',
        );
      }
    }
  }

  // ── Misc ──────────────────────────────────────────────────────────

  Future<void> cancelTransfer(String jobId) async {
    // TCP abort not yet implemented — mark as error.
    debugPrint('[TCP] cancelTransfer($jobId) — not implemented');
  }

  void dismissError() {
    if (mounted) state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    if (_isReceiver) {
      _tcpService.stopServer();
    }
    super.dispose();
  }
}

/// Provider for [TransferNotifier].
///
/// [peerName] is passed via family parameter so the TCP service can log
/// and store the remote peer's display name in each [TransferJob].
final transferProvider =
    StateNotifierProvider.autoDispose.family<TransferNotifier, TransferState, String>(
  (ref, peerName) => TransferNotifier(peerName: peerName),
);
