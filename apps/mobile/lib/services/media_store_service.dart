import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

/// Dart wrapper for the native MediaStore save channel.
///
/// After a file is received via TCP into a temp location, call [saveToPublic]
/// to move it into the appropriate public folder:
///
///   image/* → Pictures/EtherSynapse/
///   video/* → Movies/EtherSynapse/
///   audio/* → Music/EtherSynapse/
///   other   → Downloads/EtherSynapse/
///
/// On Android 29+, MediaStore.IS_PENDING is used so that Gallery apps only
/// see the file once it is fully written.  On Android <29, the file is copied
/// to the legacy public directory and a MediaScanner broadcast is sent.
class MediaStoreService {
  static const _channel = MethodChannel('dev.ethersynapse/media');

  /// Saves [srcPath] (temp file) to a public folder, returning the final path.
  ///
  /// [fileName] is the display name (e.g. "photo.jpg").
  /// [mimeType] if null is inferred from the extension.
  static Future<String> saveToPublic({
    required String srcPath,
    required String fileName,
    String? mimeType,
  }) async {
    final resolvedMime =
        mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';

    debugPrint('[FILE SAVE] saving "$fileName" (mime: $resolvedMime)');
    debugPrint('[FILE SAVE] source: $srcPath');

    if (!Platform.isAndroid) {
      // Non-Android: just return the temp path — no public storage logic needed.
      debugPrint('[FILE SAVE] non-Android — returning temp path');
      return srcPath;
    }

    try {
      final publicPath = await _channel.invokeMethod<String>('saveToPublic', {
        'srcPath': srcPath,
        'fileName': fileName,
        'mimeType': resolvedMime,
      });
      debugPrint('[FILE SAVE] success — public path: $publicPath');
      return publicPath ?? srcPath;
    } on PlatformException catch (e) {
      debugPrint('[FILE SAVE] platform error: $e — falling back to temp path');
      return srcPath;
    }
  }

  /// Creates a temporary receive directory inside the app cache.
  ///
  /// Files here are moved to public storage immediately after full receipt.
  static Future<String> getTempReceiveDir() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory('${cache.path}/ether_recv');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Infers the MIME type for [fileName].
  static String mimeTypeOf(String fileName) =>
      lookupMimeType(fileName) ?? 'application/octet-stream';
}
