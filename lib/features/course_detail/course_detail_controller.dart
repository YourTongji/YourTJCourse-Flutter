import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../core/storage/client_id_store.dart';
import '../../domain/models/ai_summary.dart';
import '../../domain/models/course_detail.dart';
import '../../domain/models/report_reason.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/review_repository.dart';

final courseDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CourseDetailController, CourseDetailState, int>(
      CourseDetailController.new,
    );

class CourseDetailState {
  const CourseDetailState({
    required this.detail,
    required this.relatedCourses,
    required this.hiddenReviewIds,
    this.aiSummary,
    this.aiSummaryError,
    this.isAiSummaryLoading = false,
    this.isAiSummaryExpanded = false,
  });

  final CourseDetail detail;
  final RelatedCourses relatedCourses;
  final Set<int> hiddenReviewIds;
  final AiSummaryData? aiSummary;
  final String? aiSummaryError;
  final bool isAiSummaryLoading;
  final bool isAiSummaryExpanded;

  List<Review> get visibleReviews {
    return detail.reviews
        .where((review) => !hiddenReviewIds.contains(review.id))
        .toList(growable: false);
  }

  CourseDetailState copyWith({
    CourseDetail? detail,
    RelatedCourses? relatedCourses,
    Set<int>? hiddenReviewIds,
    AiSummaryData? aiSummary,
    String? aiSummaryError,
    bool? isAiSummaryLoading,
    bool? isAiSummaryExpanded,
    bool clearAiSummary = false,
    bool clearAiSummaryError = false,
  }) {
    return CourseDetailState(
      detail: detail ?? this.detail,
      relatedCourses: relatedCourses ?? this.relatedCourses,
      hiddenReviewIds: hiddenReviewIds ?? this.hiddenReviewIds,
      aiSummary: clearAiSummary ? null : aiSummary ?? this.aiSummary,
      aiSummaryError: clearAiSummaryError
          ? null
          : aiSummaryError ?? this.aiSummaryError,
      isAiSummaryLoading: isAiSummaryLoading ?? this.isAiSummaryLoading,
      isAiSummaryExpanded: isAiSummaryExpanded ?? this.isAiSummaryExpanded,
    );
  }
}

class CourseDetailController extends AsyncNotifier<CourseDetailState> {
  CourseDetailController(this._courseId);

  final int _courseId;
  late CourseRepository _courseRepository;
  late ReviewRepository _reviewRepository;
  late CancelToken _cancelToken;
  late HiddenReviewStore _hiddenReviewStore;
  late String _clientId;

  @override
  Future<CourseDetailState> build() async {
    _courseRepository = ref.watch(courseRepositoryProvider);
    _reviewRepository = ref.watch(reviewRepositoryProvider);
    _hiddenReviewStore = const HiddenReviewStore();
    _cancelToken = scopedCancelToken(ref);
    _clientId = await ClientIdStore().loadOrCreate();

    try {
      final detail = await _courseRepository.getCourseDetail(
        id: _courseId,
        clientId: _clientId,
        cancelToken: _cancelToken,
      );
      final relatedCourses = await _loadRelatedCourses();
      final hiddenReviewIds = await _hiddenReviewStore.load();
      return CourseDetailState(
        detail: detail,
        relatedCourses: relatedCourses,
        hiddenReviewIds: hiddenReviewIds,
      );
    } catch (error) {
      if (isRequestCancellation(error) && state.value != null) {
        return state.value!;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<RelatedCourses> _loadRelatedCourses() async {
    try {
      return await _courseRepository.getRelatedCourses(
        id: _courseId,
        cancelToken: _cancelToken,
      );
    } catch (error) {
      if (isRequestCancellation(error)) rethrow;
      return const RelatedCourses(
        teacherOtherCourses: [],
        sameCourseOtherTeachers: [],
      );
    }
  }

  Future<void> loadAiSummary({bool refresh = false}) async {
    final current = state.value;
    if (current == null || current.isAiSummaryLoading) return;
    state = AsyncData(
      current.copyWith(
        isAiSummaryLoading: true,
        isAiSummaryExpanded: true,
        clearAiSummaryError: true,
        clearAiSummary: refresh,
      ),
    );
    try {
      final response = await _courseRepository.getAiSummary(
        courseId: _courseId,
        refresh: refresh,
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          aiSummary: response.data,
          isAiSummaryLoading: false,
          isAiSummaryExpanded: true,
          clearAiSummaryError: true,
        ),
      );
    } catch (error) {
      if (isRequestCancellation(error)) rethrow;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          aiSummaryError: error.toString(),
          isAiSummaryLoading: false,
          isAiSummaryExpanded: true,
        ),
      );
    }
  }

  void toggleAiSummaryExpanded() {
    final current = state.value;
    if (current == null) return;
    if (current.aiSummary == null &&
        current.aiSummaryError == null &&
        !current.isAiSummaryLoading) {
      unawaited(loadAiSummary());
      return;
    }
    state = AsyncData(
      current.copyWith(isAiSummaryExpanded: !current.isAiSummaryExpanded),
    );
  }

  Future<void> toggleLike(int reviewId) async {
    final current = state.value;
    if (current == null) return;
    final review = current.detail.reviews
        .where((item) => item.id == reviewId)
        .firstOrNull;
    if (review == null) return;

    try {
      final response = review.liked
          ? await _reviewRepository.unlikeReview(
              reviewId: reviewId,
              clientId: _clientId,
              cancelToken: _cancelToken,
            )
          : await _reviewRepository.likeReview(
              reviewId: reviewId,
              clientId: _clientId,
              cancelToken: _cancelToken,
            );
      final updated = review.copyWith(
        liked: response.liked,
        likeCount: response.likeCount,
      );
      state = AsyncData(
        current.copyWith(detail: current.detail.replacingReview(updated)),
      );
    } catch (error, stackTrace) {
      if (isRequestCancellation(error)) return;
      state = AsyncError<CourseDetailState>(error, stackTrace);
      state = AsyncData(current);
    }
  }

  Future<bool> reportReview(int reviewId, ReportReason reason) async {
    try {
      final response = await _reviewRepository.reportReview(
        reviewId: reviewId,
        reason: reason,
        clientId: _clientId,
        cancelToken: _cancelToken,
      );
      return response.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> hideReview(int reviewId) async {
    final current = state.value;
    if (current == null) return;
    final hidden = {...current.hiddenReviewIds, reviewId};
    await _hiddenReviewStore.save(hidden);
    state = AsyncData(current.copyWith(hiddenReviewIds: hidden));
  }

  Future<bool> createReview({
    required int rating,
    required String comment,
    required String semester,
    required String captchaToken,
    String? reviewerName,
    String? reviewerAvatar,
  }) async {
    try {
      final response = await _reviewRepository.createReview(
        courseId: _courseId,
        rating: rating,
        comment: comment,
        semester: semester,
        captchaToken: captchaToken,
        reviewerName: reviewerName,
        reviewerAvatar: reviewerAvatar,
        cancelToken: _cancelToken,
      );
      if (!response.success) return false;
      ref.invalidateSelf();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class HiddenReviewStore {
  const HiddenReviewStore();

  static const _key = 'de.yourtj.course.hiddenReviewIds';

  Future<Set<int>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
            .getStringList(_key)
            ?.map(int.tryParse)
            .whereType<int>()
            .toSet() ??
        <int>{};
  }

  Future<void> save(Set<int> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      ids.map((id) => id.toString()).toList(growable: false)..sort(),
    );
  }
}
