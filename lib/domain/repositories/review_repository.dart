import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/json_helpers.dart';
import '../models/report_reason.dart';
import '../models/review.dart';
import 'local_review_store.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(apiClientProvider));
});

final captchaRepositoryProvider = Provider<CaptchaRepository>((ref) {
  return CaptchaRepository(
    ref.watch(dioProvider),
    ref.watch(appConfigProvider),
  );
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

  Future<CreateReviewResponse> createReview({
    required int courseId,
    required int rating,
    required String comment,
    required String semester,
    required String captchaToken,
    String? reviewerName,
    String? reviewerAvatar,
    String? walletUserHash,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/review',
      body: {
        'course_id': courseId,
        'rating': rating,
        'comment': comment,
        'semester': semester,
        'turnstile_token': captchaToken,
        if (reviewerName != null && reviewerName.trim().isNotEmpty)
          'reviewer_name': reviewerName.trim(),
        if (reviewerAvatar != null && reviewerAvatar.trim().isNotEmpty)
          'reviewer_avatar': reviewerAvatar.trim(),
        if (walletUserHash != null && walletUserHash.trim().isNotEmpty)
          'walletUserHash': walletUserHash.trim(),
      },
      cancelToken: cancelToken,
      decode: CreateReviewResponse.fromJson,
    );
  }

  Future<UpdateReviewResponse> updateReview({
    required int reviewId,
    required int rating,
    required String comment,
    required String semester,
    required String captchaToken,
    String? editToken,
    String? walletUserHash,
    String? reviewerName,
    String? reviewerAvatar,
    CancelToken? cancelToken,
  }) {
    return _client.put(
      '/api/review/$reviewId',
      body: {
        'rating': rating,
        'comment': comment,
        'semester': semester,
        'turnstile_token': captchaToken,
        if (editToken != null && editToken.trim().isNotEmpty)
          'edit_token': editToken.trim(),
        if (walletUserHash != null && walletUserHash.trim().isNotEmpty)
          'walletUserHash': walletUserHash.trim(),
        if (reviewerName != null && reviewerName.trim().isNotEmpty)
          'reviewer_name': reviewerName.trim(),
        if (reviewerAvatar != null && reviewerAvatar.trim().isNotEmpty)
          'reviewer_avatar': reviewerAvatar.trim(),
      },
      cancelToken: cancelToken,
      decode: UpdateReviewResponse.fromJson,
    );
  }

  /// Fetch reviews belonging to a wallet address.
  Future<List<LocalReviewEntry>> fetchWalletReviews(
    String userHash, {
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get<List<LocalReviewEntry>>(
      '/api/review/by-wallet/$userHash',
      queryParameters: {'limit': '50'},
      cancelToken: cancelToken,
      decode: (json) {
        if (json is! Map) return <LocalReviewEntry>[];
        // Serverless returns {reviews: [...], pagination: {...}}
        final reviews = json['reviews'];
        if (reviews is! List) return <LocalReviewEntry>[];
        return reviews.map((item) {
          final map = asJsonMap(item);
          final review = Review.fromJson(item);
          return LocalReviewEntry(
            courseId: review.courseId,
            courseName: readString(map['course_name']) ?? '',
            courseCode: readString(map['course_code']) ?? '',
            teacherName: readString(map['teacher_name']) ?? '',
            courseRating: readDouble(map['course_rating']) ?? 0,
            reviewCount: readInt(map['review_count']) ?? 0,
            review: review,
            savedAt: review.createdAt,
          );
        }).toList(growable: false);
      },
    );
    return response;
  }
}

class CaptchaRepository {
  const CaptchaRepository(this._dio, this._config);

  final Dio _dio;
  final AppConfig _config;

  Future<CaptchaChallenge> fetchChallenge({CancelToken? cancelToken}) async {
    final response = await _dio.get<Object?>(
      '${_config.captchaApiBaseUrl}/api/captcha',
      cancelToken: cancelToken,
    );
    return CaptchaChallenge.fromJson(response.data, _config.captchaApiBaseUrl);
  }

  Future<CaptchaVerifyResponse> verify({
    required String puzzleToken,
    required List<int> selectedIndices,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Object?>(
      '${_config.captchaApiBaseUrl}/api/verify',
      data: {'puzzle_token': puzzleToken, 'selected_indices': selectedIndices},
      cancelToken: cancelToken,
    );
    return CaptchaVerifyResponse.fromJson(response.data);
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

class CreateReviewResponse {
  const CreateReviewResponse({required this.success, this.reviewId});

  factory CreateReviewResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CreateReviewResponse(
      success: readBool(map['success']) ?? false,
      reviewId: readInt(map['reviewId']),
    );
  }

  final bool success;
  final int? reviewId;
}

class UpdateReviewResponse {
  const UpdateReviewResponse({required this.success});

  factory UpdateReviewResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return UpdateReviewResponse(success: readBool(map['success']) ?? false);
  }

  final bool success;
}

class CaptchaChallenge {
  const CaptchaChallenge({
    required this.puzzleToken,
    required this.prompt,
    required this.images,
  });

  factory CaptchaChallenge.fromJson(Object? json, String baseUrl) {
    final map = asJsonMap(json);
    return CaptchaChallenge(
      puzzleToken: readString(map['puzzle_token']) ?? '',
      prompt: readString(map['prompt']) ?? '请选择符合条件的图片',
      images: readStringList(map['images'])
          .map((url) => url.startsWith('http') ? url : '$baseUrl$url')
          .toList(growable: false),
    );
  }

  final String puzzleToken;
  final String prompt;
  final List<String> images;
}

class CaptchaVerifyResponse {
  const CaptchaVerifyResponse({
    required this.success,
    this.token,
    this.message,
  });

  factory CaptchaVerifyResponse.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CaptchaVerifyResponse(
      success: readBool(map['success']) ?? false,
      token: readString(map['token']),
      message: readString(map['message']),
    );
  }

  final bool success;
  final String? token;
  final String? message;
}
