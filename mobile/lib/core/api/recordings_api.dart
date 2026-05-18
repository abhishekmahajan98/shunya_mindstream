import '../models/recording.dart';
import 'api_client.dart';

class RecordingsApi {
  static Future<List<Recording>> list() async {
    final resp = await dio.get('/api/recordings');
    return (resp.data as List<dynamic>)
        .map((r) => Recording.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<Recording> save({
    required String type,
    String? promptId,
    required String transcript,
    int? durationSecs,
    int? wordCount,
    String? audioPath,
  }) async {
    final resp = await dio.post('/api/recordings', data: {
      'type': type,
      if (promptId != null) 'prompt_id': promptId,
      'transcript': transcript,
      if (durationSecs != null) 'duration_secs': durationSecs,
      if (wordCount != null) 'word_count': wordCount,
      if (audioPath != null) 'audio_path': audioPath,
    });
    return Recording.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<String> getAudioUrl(String recordingId) async {
    final resp = await dio.get('/api/recordings/$recordingId/audio');
    return resp.data['url'] as String;
  }
}
