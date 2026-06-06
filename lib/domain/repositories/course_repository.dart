import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/ai_summary.dart';
import '../models/course.dart';
import '../models/course_detail.dart';
import '../models/paginated_response.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(ref.watch(apiClientProvider));
});

class CourseRepository {
  const CourseRepository(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<Course>> getCourses({
    String? query,
    List<String>? departments,
    bool onlyWithReviews = false,
    int page = 1,
    int limit = 20,
    bool includeTotal = false,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/courses',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (departments != null && departments.isNotEmpty)
          'departments': departments.join(','),
        if (onlyWithReviews) 'onlyWithReviews': 'true',
        'page': page,
        'limit': limit.clamp(1, 50),
        if (includeTotal) 'includeTotal': 'true',
      },
      cancelToken: cancelToken,
      decode: (json) => PaginatedResponse.fromJson(json, Course.fromJson),
    );
  }

  Future<CourseDetail> getCourseDetail({
    required int id,
    String? clientId,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/course/$id',
      queryParameters: {
        if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      },
      cancelToken: cancelToken,
      decode: CourseDetail.fromJson,
    );
  }

  Future<RelatedCourses> getRelatedCourses({
    required int id,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/course/$id/related',
      cancelToken: cancelToken,
      decode: RelatedCourses.fromJson,
    );
  }

  Future<AiSummaryResponse> getAiSummary({
    required int courseId,
    bool refresh = false,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/course/$courseId/summary',
      queryParameters: {if (refresh) 'refresh': 'true'},
      cancelToken: cancelToken,
      decode: AiSummaryResponse.fromJson,
    );
  }

  Future<CourseDetail> getCourseByCode({
    required String code,
    String? teacherCode,
    String? teacherName,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/course/by-code/$code',
      queryParameters: {
        if (teacherCode != null && teacherCode.isNotEmpty)
          'teacherCode': teacherCode,
        if (teacherName != null && teacherName.isNotEmpty)
          'teacherName': teacherName,
      },
      cancelToken: cancelToken,
      decode: CourseDetail.fromJson,
    );
  }
}
