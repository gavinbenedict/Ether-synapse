import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';
import '../../../services/media_store_service.dart';

/// Handles raw TCP file transfers using dart:io Sockets.
///
/// Protocol (both directions):
///   1. Sender connects to Receiver's LAN IP on port [transferPort].
///   2. Sender writes 8-byte big-endian Int64 = length of JSON metadata.
///   3. Sender writes JSON metadata: {filename, size}.
///   4. Sender streams the raw file bytes.
///   5. Receiver reassembles the stream and saves to public storage.
class TcpTransferService {
  ServerSocket? _serverSocket;
  Socket? _clientSocket;

  /// Guard: true while a send is in-flight. Prevents concurrent sends.
  bool _isSending = false;

  final _progressController = StreamController<TransferJob>.broadcast();
  Stream<TransferJob> get progressStream => _progressController.stream;

  final _uuid = const Uuid();

  static const int transferPort = 8080;

  // ── Receiver side ─────────────────────────────────────────────────

  /// Start the TCP server bound to all interfaces.
  ///
  /// [peerName] is the sender's display name (passed from negotiation) so it
  /// can be stored in the completed [TransferJob].
  Future<void> startServer({String peerName = 'Unknown'}) async {
    if (_serverSocket != null) {
      debugPrint('[TCP SERVER] Already running on port $transferPort');
      return;
    }

    try {
      debugPrint('[TCP SERVER] Starting server on port $transferPort...');
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        transferPort,
        shared: false,
      );
      debugPrint('[TCP SERVER] Bound on IP: ${_serverSocket!.address.address}');
      debugPrint('[TCP SERVER] Bound on Port: ${_serverSocket!.port}');
      debugPrint('[TCP SERVER] Listening for incoming connections...');

      _serverSocket!.listen(
        (Socket client) {
          debugPrint(
            '[TCP SERVER] Incoming connection from '
            '${client.remoteAddress.address}:${client.remotePort}',
          );
          _handleIncomingClient(client, peerName: peerName);
        },
        onError: (Object e) => debugPrint('[TCP SERVER] Server error: $e'),
        onDone: () => debugPrint('[TCP SERVER] Server socket closed'),
      );
    } catch (e) {
      debugPrint('[TCP SERVER] Failed to start: $e');
      _serverSocket = null;
      rethrow;
    }
  }

  /// Stop the receiver TCP server and release the port.
  Future<void> stopServer() async {
    if (_serverSocket == null) return;
    debugPrint('[TCP SERVER] Stopping...');
    await _serverSocket?.close();
    _serverSocket = null;
    debugPrint('[TCP SERVER] Stopped');
  }

  bool get isRunning => _serverSocket != null;

  // ── Sender side ───────────────────────────────────────────────────

  /// Whether a send is currently in-flight.
  bool get isSending => _isSending;

  /// Connect to [hostIp]:[port] and stream [file].
  ///
  /// Throws [StateError] if a transfer is already in progress.
  /// Emits [TransferJob] snapshots on [progressStream] throughout.
  Future<void> sendFile(
    String hostIp,
    File file, {
    int port = transferPort,
    String peerName = 'Unknown',
  }) async {
    if (_isSending) {
      throw StateError('A transfer is already in progress. ')
        ..stackTrace; // re-use same error type
    }
    _isSending = true;

    final jobId = _uuid.v4();
    final fileName = file.path.split(Platform.pathSeparator).last;
    final mimeType = MediaStoreService.mimeTypeOf(fileName);
    int fileSize = 0;

    try {
      fileSize = (await file.stat()).size;

      var job = TransferJob(
        id: jobId,
        fileName: fileName,
        fileSize: fileSize,
        status: TransferStatus.transferring,
        direction: TransferDirection.sent,
        mimeType: mimeType,
        peerName: peerName,
        localPath: file.path,
        startedAt: DateTime.now(),
      );
      _progressController.add(job);

      debugPrint('[TCP CLIENT] Connecting to $hostIp:$port...');
      _clientSocket = await Socket.connect(
        hostIp,
        port,
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[TCP CLIENT] Connection success — $hostIp:$port');

      final metaBytes = utf8.encode(
        jsonEncode({'filename': fileName, 'size': fileSize}),
      );
      final header = ByteData(8)..setInt64(0, metaBytes.length, Endian.big);
      _clientSocket!.add(header.buffer.asUint8List());
      _clientSocket!.add(metaBytes);
      debugPrint('[TCP CLIENT] Metadata sent (${metaBytes.length} bytes)');

      int bytesSent = 0;
      await for (final chunk in file.openRead()) {
        _clientSocket!.add(chunk);
        bytesSent += chunk.length;
        job = job.copyWith(
          bytesTransferred: bytesSent,
          status: TransferStatus.transferring,
        );
        _progressController.add(job);
      }

      await _clientSocket!.flush();
      await _clientSocket!.close();
      _clientSocket = null;

      debugPrint('[TCP CLIENT] Transfer complete — $bytesSent bytes sent');

      job = job.copyWith(
        status: TransferStatus.complete,
        bytesTransferred: fileSize,
        completedAt: DateTime.now(),
      );
      _progressController.add(job);
    } catch (e) {
      debugPrint('[TCP CLIENT] Failed: $e');
      _clientSocket?.destroy();
      _clientSocket = null;
      _progressController.add(TransferJob(
        id: jobId,
        fileName: fileName,
        fileSize: fileSize,
        status: TransferStatus.error,
        direction: TransferDirection.sent,
        mimeType: mimeType,
        peerName: peerName,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      ));
      rethrow;
    } finally {
      // Always release the guard — success, failure, cancellation, or timeout.
      _isSending = false;
    }
  }

  // ── Incoming client handler ───────────────────────────────────────

  void _handleIncomingClient(Socket client, {required String peerName}) async {
    int bytesReceived = 0;
    int? totalBytes;
    int? metaLength;
    String? fileName;
    String? mimeType;
    String? tempPath;
    IOSink? fileSink;

    final jobId = _uuid.v4();
    TransferJob? currentJob;
    final buffer = <int>[];

    // Write received bytes to a temp file first, then move to public storage.
    final tempDir = await MediaStoreService.getTempReceiveDir();

    client.listen(
      (Uint8List data) async {
        buffer.addAll(data);

        // State 1: Read 8-byte header → metadata length
        if (metaLength == null && buffer.length >= 8) {
          final bd = ByteData.sublistView(Uint8List.fromList(buffer.sublist(0, 8)));
          metaLength = bd.getInt64(0, Endian.big);
          buffer.removeRange(0, 8);
          debugPrint('[TCP SERVER] Metadata length: $metaLength bytes');
        }

        // State 2: Read JSON metadata
        if (metaLength != null && fileName == null && buffer.length >= metaLength!) {
          final meta = jsonDecode(utf8.decode(buffer.sublist(0, metaLength!)))
              as Map<String, dynamic>;
          fileName = meta['filename'] as String;
          totalBytes = meta['size'] as int;
          mimeType = MediaStoreService.mimeTypeOf(fileName!);

          // Unique temp filename to avoid collisions
          final ts = DateTime.now().millisecondsSinceEpoch;
          tempPath = '$tempDir/${ts}_$fileName';

          fileSink = File(tempPath!).openWrite();
          buffer.removeRange(0, metaLength!);

          currentJob = TransferJob(
            id: jobId,
            fileName: fileName!,
            fileSize: totalBytes!,
            status: TransferStatus.transferring,
            direction: TransferDirection.received,
            mimeType: mimeType,
            peerName: peerName,
            startedAt: DateTime.now(),
          );
          _progressController.add(currentJob!);
          debugPrint(
            '[TCP SERVER] Receiving: $fileName ($totalBytes bytes) '
            'mime: $mimeType',
          );
        }

        // State 3: Write file chunks
        if (fileSink != null && buffer.isNotEmpty) {
          fileSink!.add(buffer.toList());
          bytesReceived += buffer.length;
          buffer.clear();
          currentJob = currentJob!.copyWith(bytesTransferred: bytesReceived);
          _progressController.add(currentJob!);
        }
      },
      onDone: () async {
        debugPrint(
          '[TCP SERVER] Done — received $bytesReceived / '
          '${totalBytes ?? 0} bytes',
        );
        await fileSink?.flush();
        await fileSink?.close();
        client.destroy();

        if (currentJob == null || tempPath == null || fileName == null) return;

        // Move from temp to public storage via MediaStore
        String publicPath = tempPath!;
        try {
          publicPath = await MediaStoreService.saveToPublic(
            srcPath: tempPath!,
            fileName: fileName!,
            mimeType: mimeType,
          );
          debugPrint('[FILE SAVE] path=$publicPath');

          // Delete temp file after successful copy
          try {
            await File(tempPath!).delete();
          } catch (_) {}
        } catch (e) {
          debugPrint('[FILE SAVE] MediaStore failed, keeping temp: $e');
        }

        // Generate thumbnail
        String? thumbnailPath;
        try {
          thumbnailPath = await _generateThumbnail(publicPath, mimeType ?? '');
          if (thumbnailPath != null) {
            debugPrint('[THUMBNAIL] generated');
            debugPrint('[THUMBNAIL] path=$thumbnailPath');
          }
        } catch (e) {
          debugPrint('[THUMBNAIL] Failed: $e');
        }

        currentJob = currentJob!.copyWith(
          status: TransferStatus.complete,
          bytesTransferred: bytesReceived,
          completedAt: DateTime.now(),
          localPath: publicPath,
          thumbnailPath: thumbnailPath,
        );
        _progressController.add(currentJob!);
        debugPrint('[FILE SAVE] success — ${currentJob!.localPath}');
      },
      onError: (Object e) async {
        debugPrint('[TCP SERVER] Client error: $e');
        await fileSink?.close();
        client.destroy();
        if (currentJob != null) {
          currentJob = currentJob!.copyWith(
            status: TransferStatus.error,
            errorMessage: e.toString(),
            completedAt: DateTime.now(),
          );
          _progressController.add(currentJob!);
        }
      },
    );
  }

  // ── Thumbnail generation ─────────────────────────────────────────

  /// Returns the path to a thumbnail for [filePath].
  ///
  /// Images: returns [filePath] directly (always a real file path at receive
  ///   time; content URIs are handled at display time by [_LocalOrContentImage]).
  ///
  /// Videos: generates a JPEG thumb in [getApplicationSupportDirectory()]/
  ///   thumbnails/ so it survives app restarts and device reboots.
  ///   Re-uses an existing thumb file when the hash matches.
  Future<String?> _generateThumbnail(String filePath, String mimeType) async {
    final category = mimeType.split('/').first;
    if (category == 'image') {
      // For images, the thumbnail is the image itself.  We store the path
      // (or content URI) as-is; the display widget handles both forms.
      return filePath;
    }
    if (category == 'video') {
      // Persist to app-support — survives cache eviction and reboots.
      final supportDir = await getApplicationSupportDirectory();
      final thumbDir = Directory('${supportDir.path}/thumbnails');
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);

      // Deterministic filename based on the source path.
      final thumbName =
          '${filePath.hashCode.abs()}_thumb.jpg';
      final thumbFile = File('${thumbDir.path}/$thumbName');

      // Re-use if already generated.
      if (await thumbFile.exists()) {
        debugPrint('[THUMBNAIL] re-using cached: ${thumbFile.path}');
        return thumbFile.path;
      }

      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: filePath,
        thumbnailPath: thumbDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 75,
      );

      // Rename to deterministic name so we can find it next time.
      if (thumbPath != null && thumbPath != thumbFile.path) {
        try {
          await File(thumbPath).rename(thumbFile.path);
          return thumbFile.path;
        } catch (_) {
          return thumbPath; // rename failed — keep generated path
        }
      }
      return thumbPath;
    }
    return null; // Documents/audio use icon-based display
  }
}
