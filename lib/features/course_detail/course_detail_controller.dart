import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../core/storage/client_id_store.dart';
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
  });

  final CourseDetail detail;
  final RelatedCourses relatedCourses;
  final Set<int> hiddenReviewIds;

  List<Review> get visibleReviews {
    return detail.reviews
        .where((review) => !hiddenReviewIds.contains(review.id))
        .toList(growable: false);
  }

  CourseDetailState copyWith({
    CourseDetail? detail,
    RelatedCourses? relatedCourses,
    Set<int>? hiddenReviewIds,
  }) {
    return CourseDetailState(
      detail: detail ?? this.detail,
      relatedCourses: relatedCourses ?? this.relatedCourses,
      hiddenReviewIds: hiddenReviewIds ?? this.hiddenReviewIds,
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
      final results = await Future.wait([
        _courseRepository.getCourseDetail(
          id: _courseId,
          clientId: _clientId,
          cancelToken: _cancelToken,
        ),
        _courseRepository.getRelatedCourses(
          id: _courseId,
          cancelToken: _cancelToken,
        ),
        _hiddenReviewStore.load(),
      ]);
      return CourseDetailState(
        detail: results[0] as CourseDetail,
        relatedCourses: results[1] as RelatedCourses,
        hiddenReviewIds: results[2] as Set<int>,
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
