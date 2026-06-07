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
import '../../domain/repositories/local_review_store.dart';
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
    required this.favoriteReviewIds,
    this.aiSummary,
    this.aiSummaryError,
    this.isAiSummaryLoading = false,
    this.isAiSummaryExpanded = false,
  });

  final CourseDetail detail;
  final RelatedCourses relatedCourses;
  final Set<int> hiddenReviewIds;
  final Set<int> favoriteReviewIds;
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
    Set<int>? favoriteReviewIds,
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
      favoriteReviewIds: favoriteReviewIds ?? this.favoriteReviewIds,
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
  late LocalReviewStore _localReviewStore;
  late CancelToken _cancelToken;
  late HiddenReviewStore _hiddenReviewStore;
  late String _clientId;

  CourseDetail get currentDetail => state.value!.detail;

  @override
  Future<CourseDetailState> build() async {
    _courseRepository = ref.watch(courseRepositoryProvider);
    _reviewRepository = ref.watch(reviewRepositoryProvider);
    _localReviewStore = ref.watch(localReviewStoreProvider);
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
      final favoriteReviewIds = await _localReviewStore.loadFavoriteIds();
      return CourseDetailState(
        detail: detail,
        relatedCourses: relatedCourses,
        hiddenReviewIds: hiddenReviewIds,
        favoriteReviewIds: favoriteReviewIds,
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
    final review = current.detail.reviews
        .where((item) => item.id == reviewId)
        .firstOrNull;
    final hidden = {...current.hiddenReviewIds, reviewId};
    await _hiddenReviewStore.save(hidden);
    if (review != null) {
      await _localReviewStore.upsertHidden(_entryFor(current, review));
    }
    state = AsyncData(current.copyWith(hiddenReviewIds: hidden));
  }

  Future<void> restoreReview(int reviewId) async {
    final current = state.value;
    if (current == null) return;
    final hidden = {...current.hiddenReviewIds}..remove(reviewId);
    await _hiddenReviewStore.save(hidden);
    await _localReviewStore.removeHidden(reviewId);
    state = AsyncData(current.copyWith(hiddenReviewIds: hidden));
  }

  Future<void> toggleFavorite(int reviewId) async {
    final current = state.value;
    if (current == null) return;
    final review = current.detail.reviews
        .where((item) => item.id == reviewId)
        .firstOrNull;
    if (review == null) return;
    final favoriteIds = {...current.favoriteReviewIds};
    if (favoriteIds.contains(reviewId)) {
      favoriteIds.remove(reviewId);
      await _localReviewStore.removeFavorite(reviewId);
    } else {
      favoriteIds.add(reviewId);
      await _localReviewStore.upsertFavorite(_entryFor(current, review));
    }
    state = AsyncData(current.copyWith(favoriteReviewIds: favoriteIds));
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
      if (response.reviewId != null) {
        final current = state.value;
        if (current != null) {
          final review = Review(
            id: response.reviewId!,
            sqid: response.reviewId!.toString(),
            courseId: _courseId,
            semester: semester,
            rating: rating,
            comment: comment,
            createdAt: DateTime.now().toIso8601String(),
            likeCount: 0,
            liked: false,
            reviewerName: reviewerName,
            reviewerAvatar: reviewerAvatar,
          );
          await _localReviewStore.upsertMine(_entryFor(current, review));
        }
      }
      ref.invalidateSelf();
      return true;
    } catch (_) {
      return false;
    }
  }

  LocalReviewEntry _entryFor(CourseDetailState current, Review review) {
    final course = current.detail;
    return LocalReviewEntry(
      courseId: course.id,
      courseName: course.name,
      courseCode: course.code,
      teacherName: course.teacherName,
      courseRating: course.rating,
      reviewCount: course.reviewCount,
      review: review,
      savedAt: DateTime.now().toIso8601String(),
    );
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
