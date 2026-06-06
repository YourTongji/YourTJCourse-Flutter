import 'json_helpers.dart';

class AiSummaryResponse {
  const AiSummaryResponse({
    required this.data,
    required this.generatedAt,
    this.cache,
  });

  factory AiSummaryResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return AiSummaryResponse(
      data: AiSummaryData.fromJson(map['data']),
      generatedAt: readInt(map['generatedAt']) ?? 0,
      cache: readString(map['cache']),
    );
  }

  final AiSummaryData data;
  final int generatedAt;
  final String? cache;
}

class AiSummaryData {
  const AiSummaryData({
    required this.ratingConsensus,
    required this.keywords,
    required this.pros,
    required this.cons,
    required this.representative,
  });

  factory AiSummaryData.fromJson(Object? json) {
    final map = asJsonMap(json);
    final representativeJson = map['representative'];
    return AiSummaryData(
      ratingConsensus: readString(map['rating_consensus']) ?? '',
      keywords: readStringList(map['keywords']),
      pros: readStringList(map['pros']),
      cons: readStringList(map['cons']),
      representative: representativeJson is List
          ? representativeJson
                .map(RepresentativeReview.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String ratingConsensus;
  final List<String> keywords;
  final List<String> pros;
  final List<String> cons;
  final List<RepresentativeReview> representative;

  bool get hasContent {
    return ratingConsensus != '数据不足' &&
        (keywords.isNotEmpty || pros.isNotEmpty || cons.isNotEmpty);
  }
}

class RepresentativeReview {
  const RepresentativeReview({required this.text, required this.sentiment});

  factory RepresentativeReview.fromJson(Object? json) {
    final map = asJsonMap(json);
    return RepresentativeReview(
      text: readString(map['text']) ?? '',
      sentiment: readString(map['sentiment']) ?? '',
    );
  }

  final String text;
  final String sentiment;
}
