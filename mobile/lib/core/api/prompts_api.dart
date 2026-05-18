import '../models/prompt.dart';
import '../models/prompt_responses_result.dart';
import 'api_client.dart';

class PromptsApi {
  static Future<List<Prompt>> list() async {
    final resp = await dio.get('/api/prompts');
    return (resp.data as List<dynamic>)
        .map((p) => Prompt.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  static Future<Prompt> create({
    required String title,
    String? description,
    String? deadline,
  }) async {
    final resp = await dio.post('/api/prompts', data: {
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      if (deadline != null) 'deadline': deadline,
    });
    return Prompt.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Prompt> updateStatus(String id, String status) async {
    final resp = await dio.patch('/api/prompts/$id', data: {'status': status});
    return Prompt.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<PromptResponsesResult> getResponses(String promptId) async {
    final resp = await dio.get('/api/prompts/$promptId/responses');
    return PromptResponsesResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
