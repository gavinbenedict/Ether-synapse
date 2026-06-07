import 'dart:math' as math;

/// File size formatting utilities.
abstract final class FileSizeUtils {
  FileSizeUtils._();

  /// Formats [bytes] as a human-readable string.
  ///
  /// Examples:
  ///   - 0       → "0 B"
  ///   - 1024    → "1.0 KB"
  ///   - 1048576 → "1.0 MB"
  static String format(int bytes) {
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor();
    final value = bytes / math.pow(1024, i);

    // Show no decimals for bytes; one decimal for all others.
    final formatted = i == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    return '$formatted ${units[i]}';
  }

  /// Formats a transfer speed in bytes per second.
  ///
  /// Example: 10485760 → "10.0 MB/s"
  static String formatSpeed(int bytesPerSecond) => '${format(bytesPerSecond)}/s';

  /// Estimates the remaining transfer duration.
  ///
  /// Returns `null` if [bytesPerSecond] is zero.
  static Duration? estimateRemaining({
    required int totalBytes,
    required int bytesTransferred,
    required int bytesPerSecond,
  }) {
    if (bytesPerSecond <= 0) return null;
    final remaining = totalBytes - bytesTransferred;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / bytesPerSecond).ceil());
  }

  /// Formats a [Duration] for display in a transfer progress context.
  ///
  /// Examples:
  ///   - 30 seconds  → "30s"
  ///   - 90 seconds  → "1m 30s"
  ///   - 3700 seconds → "1h 1m"
  static String formatDuration(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) {
      final s = d.inSeconds.remainder(60);
      return '${d.inMinutes}m ${s}s';
    }
    final m = d.inMinutes.remainder(60);
    return '${d.inHours}h ${m}m';
  }
}
