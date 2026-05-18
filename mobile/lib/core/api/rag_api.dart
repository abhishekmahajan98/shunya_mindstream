import '../models/rag_result.dart';
import 'api_client.dart';

class RagApi {
  static Future<RagResult> query({
    required String query,
    String? dateFrom,
    String? dateTo,
  }) async {
    final resp = await dio.post('/api/rag/query', data: {
      'query': query,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    });
    return RagResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
