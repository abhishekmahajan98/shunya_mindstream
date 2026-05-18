class RagSource {
  final String analystName;
  final String transcript;
  final double similarity;
  final String createdAt;
  final String type;

  const RagSource({
    required this.analystName,
    required this.transcript,
    required this.similarity,
    required this.createdAt,
    required this.type,
  });

  factory RagSource.fromJson(Map<String, dynamic> j) => RagSource(
        analystName: j['analyst_name'] as String? ?? 'Unknown',
        transcript: j['transcript'] as String,
        similarity: (j['similarity'] as num).toDouble(),
        createdAt: j['created_at'] as String,
        type: j['type'] as String,
      );
}

class RagResult {
  final String query;
  final String answer;
  final List<RagSource> sources;

  const RagResult({required this.query, required this.answer, required this.sources});

  factory RagResult.fromJson(Map<String, dynamic> j) => RagResult(
        query: j['query'] as String,
        answer: j['answer'] as String,
        sources: (j['sources'] as List<dynamic>)
            .map((s) => RagSource.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
