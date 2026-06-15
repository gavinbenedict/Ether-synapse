import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/transfer_job.dart';
import '../../../shared/models/transfer_status.dart';

/// Handles raw TCP file transfers using dart:io Sockets.
/// 
/// Protocol:
/// 1. Sender connects to Receiver's IP and port (default 8080).
/// 2. Sender writes 8-byte header (big-endian Int64) representing the length of the JSON metadata.
/// 3. Sender writes JSON metadata (filename, total size).
/// 4. Sender streams the file bytes in chunks.
/// 5. Receiver parses header, metadata, and writes the incoming stream to a local file.
class TcpTransferService {
  ServerSocket? _serverSocket;
  Socket? _clientSocket;

  final _progressController = StreamController<TransferJob>.broadcast();
  Stream<TransferJob> get progressStream => _progressController.stream;

  final _uuid = const Uuid();

  /// Start the receiver TCP server
  Future<void> startServer(String host, int port, String savePath) async {
    try {
      _serverSocket = await ServerSocket.bind(host, port);
      debugPrint('[EtherSynapse] TCP Server listening on \$host:\$port');

      _serverSocket?.listen((Socket client) {
        debugPrint('[EtherSynapse] Client connected: \${client.remoteAddress.address}');
        _handleIncomingClient(client, savePath);
      });
    } catch (e) {
      debugPrint('[EtherSynapse] Failed to start TCP server: \$e');
      rethrow;
    }
  }

  /// Stop the receiver TCP server
  Future<void> stopServer() async {
    await _serverSocket?.close();
    _serverSocket = null;
  }

  /// Start a file transfer as the sender
  Future<void> sendFile(String host, int port, File file) async {
    final jobId = _uuid.v4();
    final filename = file.path.split(Platform.pathSeparator).last;
    int fileSize = 0;
    
    try {
      final fileStat = await file.stat();
      fileSize = fileStat.size;
      
      var job = TransferJob(
        id: jobId,
        fileName: filename,
        fileSize: fileSize,
        status: TransferStatus.transferring,
        startedAt: DateTime.now(),
      );
      _progressController.add(job);

      _clientSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      debugPrint('[EtherSynapse] Connected to \$host:\$port');
      
      // Construct metadata
      final metadata = {
        'filename': filename,
        'size': fileSize,
      };
      
      final metaBytes = utf8.encode(jsonEncode(metadata));
      final header = ByteData(8)..setInt64(0, metaBytes.length, Endian.big);

      // Send header and metadata
      _clientSocket!.add(header.buffer.asUint8List());
      _clientSocket!.add(metaBytes);

      // Stream file
      int bytesSent = 0;
      final fileStream = file.openRead();
      
      await for (final chunk in fileStream) {
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
      debugPrint('[EtherSynapse] Transfer complete');
      
      job = job.copyWith(
        status: TransferStatus.complete,
        completedAt: DateTime.now(),
      );
      _progressController.add(job);

    } catch (e) {
      debugPrint('[EtherSynapse] TCP send error: \$e');
      _clientSocket?.destroy();
      _clientSocket = null;
      
      _progressController.add(TransferJob(
        id: jobId,
        fileName: filename,
        fileSize: fileSize,
        status: TransferStatus.error,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  void _handleIncomingClient(Socket client, String saveDirectory) async {
    int bytesReceived = 0;
    int? totalBytes;
    int? metaLength;
    String? filename;
    File? destFile;
    IOSink? fileSink;
    
    final jobId = _uuid.v4();
    TransferJob? currentJob;
    
    // Buffer for parsing header
    final buffer = <int>[];

    client.listen((Uint8List data) async {
      buffer.addAll(data);
      
      // State 1: Read 8-byte metadata header
      if (metaLength == null && buffer.length >= 8) {
        final headerBytes = Uint8List.fromList(buffer.sublist(0, 8));
        final bd = ByteData.sublistView(headerBytes);
        metaLength = bd.getInt64(0, Endian.big);
        buffer.removeRange(0, 8);
      }
      
      // State 2: Read JSON metadata
      if (metaLength != null && filename == null && buffer.length >= metaLength!) {
        final metaBytes = buffer.sublist(0, metaLength!);
        final metaStr = utf8.decode(metaBytes);
        final meta = jsonDecode(metaStr) as Map<String, dynamic>;
        
        filename = meta['filename'] as String;
        totalBytes = meta['size'] as int;
        
        currentJob = TransferJob(
          id: jobId,
          fileName: filename!,
          fileSize: totalBytes!,
          status: TransferStatus.transferring,
          startedAt: DateTime.now(),
        );
        _progressController.add(currentJob!);
        
        destFile = File('\$saveDirectory/\$filename');
        if (await destFile!.exists()) {
          // Handle duplicates
          destFile = File('\$saveDirectory/copy_\$filename');
        }
        fileSink = destFile!.openWrite();
        
        buffer.removeRange(0, metaLength!);
        debugPrint('[EtherSynapse] Receiving file: \$filename (\$totalBytes bytes)');
      }
      
      // State 3: Write file chunks
      if (fileSink != null && buffer.isNotEmpty) {
        fileSink!.add(buffer);
        bytesReceived += buffer.length;
        buffer.clear();
        
        currentJob = currentJob!.copyWith(
          bytesTransferred: bytesReceived,
        );
        _progressController.add(currentJob!);
      }
    },
    onDone: () async {
      debugPrint('[EtherSynapse] Client disconnected. Received: \$bytesReceived bytes');
      await fileSink?.flush();
      await fileSink?.close();
      client.destroy();
      
      if (currentJob != null) {
        currentJob = currentJob!.copyWith(
          status: TransferStatus.complete,
          completedAt: DateTime.now(),
        );
        _progressController.add(currentJob!);
      }
    },
    onError: (e) {
      debugPrint('[EtherSynapse] Client error: \$e');
      fileSink?.close();
      client.destroy();
      
      if (currentJob != null) {
        currentJob = currentJob!.copyWith(
          status: TransferStatus.error,
          errorMessage: e.toString(),
          completedAt: DateTime.now(),
        );
        _progressController.add(currentJob!);
      }
    });
  }
}
