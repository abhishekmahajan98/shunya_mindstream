import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/recordings_api.dart';

class SyncService {
  static const _kQueueKey = 'ms_offline_queue';
  static const _kDraftsKey = 'ms_drafts_queue';

  /// Adds a recording request to the offline queue
  static Future<void> queueRecording(Map<String, dynamic> request) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_kQueueKey) ?? [];
    
    // Add timestamp so we know when it was actually recorded
    request['local_timestamp'] = DateTime.now().toIso8601String();
    
    queue.add(jsonEncode(request));
    await prefs.setStringList(_kQueueKey, queue);
    debugPrint('[SyncService] Queued offline recording. Queue size: ${queue.length}');
  }

  /// Attempts to sync all queued recordings to the backend
  static Future<void> syncPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_kQueueKey) ?? [];
    
    if (queue.isEmpty) return;
    
    debugPrint('[SyncService] Found ${queue.length} pending offline recordings to sync.');
    
    List<String> failedQueue = [];
    
    for (String itemStr in queue) {
      try {
        final item = jsonDecode(itemStr) as Map<String, dynamic>;
        
        await RecordingsApi.save(
          type: item['type'],
          promptId: item['prompt_id'],
          transcript: item['transcript'],
          durationSecs: item['duration_secs'],
          wordCount: item['word_count'],
        );
        
        debugPrint('[SyncService] Successfully synced offline recording.');
      } catch (e) {
        debugPrint('[SyncService] Failed to sync item, keeping in queue: $e');
        failedQueue.add(itemStr);
      }
    }
    
    // Write back any items that failed
    await prefs.setStringList(_kQueueKey, failedQueue);
  }

  /// Retrieves all queued recordings
  static Future<List<Map<String, dynamic>>> getPendingRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_kQueueKey) ?? [];
    return queue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  /// Saves an explicit draft to local storage
  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList(_kDraftsKey) ?? [];
    
    draft['local_timestamp'] = DateTime.now().toIso8601String();
    drafts.add(jsonEncode(draft));
    await prefs.setStringList(_kDraftsKey, drafts);
    debugPrint('[SyncService] Saved local draft. Drafts size: ${drafts.length}');
  }

  /// Retrieves all local drafts
  static Future<List<Map<String, dynamic>>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList(_kDraftsKey) ?? [];
    return drafts.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  /// Deletes a draft from local storage at a given index
  static Future<void> deleteDraft(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final drafts = prefs.getStringList(_kDraftsKey) ?? [];
    if (index >= 0 && index < drafts.length) {
      drafts.removeAt(index);
      await prefs.setStringList(_kDraftsKey, drafts);
      debugPrint('[SyncService] Deleted draft at index $index. Remaining drafts: ${drafts.length}');
    }
  }
}
