import 'recording.dart';
import 'prompt.dart';

class PromptResponsesResult {
  final Prompt prompt;
  final List<Recording> recordings;
  final String? summary;

  const PromptResponsesResult({
    required this.prompt,
    required this.recordings,
    this.summary,
  });

  factory PromptResponsesResult.fromJson(Map<String, dynamic> j) =>
      PromptResponsesResult(
        prompt: Prompt.fromJson(j['prompt'] as Map<String, dynamic>),
        recordings: (j['recordings'] as List<dynamic>)
            .map((r) => Recording.fromJson(r as Map<String, dynamic>))
            .toList(),
        summary: j['summary'] as String?,
      );
}
