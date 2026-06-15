import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/transfer_job.dart';

/// Persists the transfer history to SharedPreferences.
///
/// History survives app restarts. Each entry is a [TransferJob] in its
/// terminal state (complete or error). Active (in-flight) jobs are never
/// persisted until they complete.
class TransferHistoryService {
  static const _key = 'transfer_history_v1';
  static const _maxEntries = 200;

  /// Load all persisted transfer history records, newest first.
  static Future<List<TransferJob>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      final jobs = raw.reversed // stored oldest-first; reverse for newest-first
          .map((s) {
            try {
              return TransferJob.fromJson(
                jsonDecode(s) as Map<String, dynamic>,
              );
            } catch (e) {
              debugPrint('[HISTORY] Failed to parse record: $e');
              return null;
            }
          })
          .whereType<TransferJob>()
          .toList();
      debugPrint('[HISTORY] Loaded ${jobs.length} records');
      return jobs;
    } catch (e) {
      debugPrint('[HISTORY] Load failed: $e');
      return [];
    }
  }

  /// Append a completed [job] to history.
  ///
  /// Only terminal (complete/error) jobs are persisted.
  /// Trims to [_maxEntries] oldest entries when the list overflows.
  static Future<void> append(TransferJob job) async {
    if (!job.isTerminal) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = List<String>.from(prefs.getStringList(_key) ?? []);

      // Remove any existing entry with the same ID (idempotent append).
      raw.removeWhere((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          return m['id'] == job.id;
        } catch (_) {
          return false;
        }
      });

      raw.add(jsonEncode(job.toJson()));

      // Trim oldest entries if over capacity.
      final trimmed =
          raw.length > _maxEntries ? raw.sublist(raw.length - _maxEntries) : raw;

      await prefs.setStringList(_key, trimmed);
      debugPrint('[HISTORY] Appended: ${job.fileName} (${job.direction.name})');
    } catch (e) {
      debugPrint('[HISTORY] Append failed: $e');
    }
  }

  /// Clear all history.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('[HISTORY] Cleared');
  }
}
