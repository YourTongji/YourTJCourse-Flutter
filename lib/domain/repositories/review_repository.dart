import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/json_helpers.dart';
import '../models/report_reason.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
});

class ReviewRepository {
  const ReviewRepository(this._client);

  final ApiClient _client;

  Future<LikeResponse> likeReview({
    required int reviewId,
    required String clientId,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/review/$reviewId/like',
      body: {'clientId': clientId},
      cancelToken: cancelToken,
      decode: LikeResponse.fromJson,
    );
  }

  Future<LikeResponse> unlikeReview({
    required int reviewId,
    required String clientId,
    CancelToken? cancelToken,
  }) {
    return _client.delete(
      '/api/review/$reviewId/like',
      body: {'clientId': clientId},
      cancelToken: cancelToken,
      decode: LikeResponse.fromJson,
    );
  }

  Future<ReportResponse> reportReview({
    required int reviewId,
    required ReportReason reason,
    required String clientId,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/review/$reviewId/report',
      body: {'reason': reason.value, 'clientId': clientId},
      cancelToken: cancelToken,
      decode: ReportResponse.fromJson,
    );
  }
}

class LikeResponse {
  const LikeResponse({
    required this.success,
    required this.liked,
    required this.likeCount,
  });

  factory LikeResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return LikeResponse(
      success: readBool(map['success']) ?? false,
      liked: readBool(map['liked']) ?? false,
      likeCount: readInt(map['like_count']) ?? 0,
    );
  }

  final bool success;
  final bool liked;
  final int likeCount;
}

class ReportResponse {
  const ReportResponse({required this.success, this.reportId});

  factory ReportResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return ReportResponse(
      success: readBool(map['success']) ?? false,
      reportId: readInt(map['reportId']),
    );
  }

  final bool success;
  final int? reportId;
}
