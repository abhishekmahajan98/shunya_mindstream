class Recording {
  final String id;
  final String analystId;
  final String type; // 'freeform' | 'prompted'
  final String? promptId;
  final String transcript;
  final int? durationSecs;
  final int? wordCount;
  final String? audioPath;
  final String createdAt;
  final Map<String, dynamic>? profiles;
  final Map<String, dynamic>? prompts;

  const Recording({
    required this.id,
    required this.analystId,
    required this.type,
    this.promptId,
    required this.transcript,
    this.durationSecs,
    this.wordCount,
    this.audioPath,
    required this.createdAt,
    this.profiles,
    this.prompts,
  });

  factory Recording.fromJson(Map<String, dynamic> j) => Recording(
        id: j['id'] as String,
        analystId: j['analyst_id'] as String,
        type: j['type'] as String,
        promptId: j['prompt_id'] as String?,
        transcript: j['transcript'] as String,
        durationSecs: j['duration_secs'] as int?,
        wordCount: j['word_count'] as int?,
        audioPath: j['audio_path'] as String?,
        createdAt: j['created_at'] as String,
        profiles: j['profiles'] as Map<String, dynamic>?,
        prompts: j['prompts'] as Map<String, dynamic>?,
      );

  String? get analystName => profiles?['full_name'] as String?;
  String? get promptTitle => prompts?['title'] as String?;
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;
}
