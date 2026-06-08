import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../domain/models/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/settings_repository.dart';

final catalogControllerProvider =
    AsyncNotifierProvider.autoDispose<CatalogController, CatalogState>(
      CatalogController.new,
    );

class CatalogState {
  const CatalogState({
    this.courses = const [],
    this.departments = const [],
    this.selectedDepartments = const [],
    this.searchText = '',
    this.onlyWithReviews = false,
    this.courseName = '',
    this.courseCode = '',
    this.teacherName = '',
    this.teacherCode = '',
    this.campus = '',
    this.faculty = '',
    this.hasMore = true,
    this.isLoadingMore = false,
    this.totalCount,
  });

  final List<Course> courses;
  final List<String> departments;
  final List<String> selectedDepartments;
  final String searchText;
  final bool onlyWithReviews;
  final String courseName;
  final String courseCode;
  final String teacherName;
  final String teacherCode;
  final String campus;
  final String faculty;
  final bool hasMore;
  final bool isLoadingMore;
  final int? totalCount;

  bool get hasAdvancedFilters {
    return selectedDepartments.isNotEmpty ||
        onlyWithReviews ||
        courseName.trim().isNotEmpty ||
        courseCode.trim().isNotEmpty ||
        teacherName.trim().isNotEmpty ||
        teacherCode.trim().isNotEmpty ||
        campus.trim().isNotEmpty ||
        faculty.trim().isNotEmpty;
  }

  int get activeFilterCount {
    return selectedDepartments.length +
        (onlyWithReviews ? 1 : 0) +
        (courseName.trim().isNotEmpty ? 1 : 0) +
        (courseCode.trim().isNotEmpty ? 1 : 0) +
        (teacherName.trim().isNotEmpty ? 1 : 0) +
        (teacherCode.trim().isNotEmpty ? 1 : 0) +
        (campus.trim().isNotEmpty ? 1 : 0) +
        (faculty.trim().isNotEmpty ? 1 : 0);
  }

  CatalogState copyWith({
    List<Course>? courses,
    List<String>? departments,
    List<String>? selectedDepartments,
    String? searchText,
    bool? onlyWithReviews,
    String? courseName,
    String? courseCode,
    String? teacherName,
    String? teacherCode,
    String? campus,
    String? faculty,
    bool? hasMore,
    bool? isLoadingMore,
    int? totalCount,
  }) {
    return CatalogState(
      courses: courses ?? this.courses,
      departments: departments ?? this.departments,
      selectedDepartments: selectedDepartments ?? this.selectedDepartments,
      searchText: searchText ?? this.searchText,
      onlyWithReviews: onlyWithReviews ?? this.onlyWithReviews,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      teacherName: teacherName ?? this.teacherName,
      teacherCode: teacherCode ?? this.teacherCode,
      campus: campus ?? this.campus,
      faculty: faculty ?? this.faculty,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class CatalogController extends AsyncNotifier<CatalogState> {
  late CourseRepository _courseRepository;
  late SettingsRepository _settingsRepository;
  late CancelToken _cancelToken;
  Timer? _searchDebounce;
  int _page = 1;

  @override
  Future<CatalogState> build() async {
    _courseRepository = ref.watch(courseRepositoryProvider);
    _settingsRepository = ref.watch(settingsRepositoryProvider);
    _cancelToken = scopedCancelToken(ref);
    ref.onDispose(() => _searchDebounce?.cancel());

    try {
      final departmentsFuture = _settingsRepository.getDepartments(
        cancelToken: _cancelToken,
      );
      final coursesFuture = _courseRepository.getCourses(
        page: _page,
        includeTotal: true,
        cancelToken: _cancelToken,
      );
      final results = await Future.wait([departmentsFuture, coursesFuture]);
      final departments = results[0] as List<String>;
      final courses = results[1] as dynamic;
      final data = (courses.data as List<Course>).toList(growable: false)
        ..shuffle(math.Random());
      final total = courses.total as int?;
      return CatalogState(
        departments: departments,
        courses: data,
        hasMore: _computeHasMore(data.length, total, courses.hasMore as bool),
        totalCount: total,
      );
    } catch (error) {
      if (isRequestCancellation(error)) {
        return state.value ?? const CatalogState();
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final value = state.value ?? const CatalogState();
    _page = 1;
    if (state.value == null) {
      state = const AsyncLoading<CatalogState>();
    }
    state = await AsyncValue.guard(() => _loadPage(value, page: 1));
  }

  Future<void> loadMore() async {
    final value = state.value;
    if (value == null || !value.hasMore || value.isLoadingMore) return;
    state = AsyncData(value.copyWith(isLoadingMore: true));
    try {
      final nextPage = _page + 1;
      final response = await _courseRepository.getCourses(
        query: value.searchText,
        departments: value.selectedDepartments,
        onlyWithReviews: value.onlyWithReviews,
        courseName: value.courseName.trim(),
        courseCode: value.courseCode.trim(),
        teacherName: value.teacherName.trim(),
        teacherCode: value.teacherCode.trim(),
        campus: value.campus.trim(),
        faculty: value.faculty.trim(),
        page: nextPage,
        cancelToken: _cancelToken,
      );
      _page = nextPage;
      final totalItems = value.totalCount;
      final allCourses = [...value.courses, ...response.data];
      state = AsyncData(
        value.copyWith(
          courses: allCourses,
          hasMore: _computeHasMore(
            allCourses.length,
            totalItems,
            response.hasMore,
          ),
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      if (isRequestCancellation(error)) {
        state = AsyncData(value.copyWith(isLoadingMore: false));
        return;
      }
      state = AsyncData(value.copyWith(isLoadingMore: false));
    }
  }

  void setSearchText(String text) {
    const maxLength = 16;
    if (text.length > maxLength) {
      text = text.substring(0, maxLength);
    }
    final value = state.value ?? const CatalogState();
    state = AsyncData(value.copyWith(searchText: text));
    _searchDebounce?.cancel();
    if (text.isEmpty) {
      refresh();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), refresh);
  }

  void toggleDepartment(String department) {
    final value = state.value ?? const CatalogState();
    final selected = [...value.selectedDepartments];
    if (selected.contains(department)) {
      selected.remove(department);
    } else {
      selected.add(department);
    }
    state = AsyncData(value.copyWith(selectedDepartments: selected));
    unawaited(refresh());
  }

  void setOnlyWithReviews(bool enabled) {
    final value = state.value ?? const CatalogState();
    state = AsyncData(value.copyWith(onlyWithReviews: enabled));
    unawaited(refresh());
  }

  void applyAdvancedFilters({
    required List<String> selectedDepartments,
    required bool onlyWithReviews,
    required String courseName,
    required String courseCode,
    required String teacherName,
    required String teacherCode,
    required String campus,
    required String faculty,
  }) {
    final value = state.value ?? const CatalogState();
    state = AsyncData(
      value.copyWith(
        selectedDepartments: selectedDepartments,
        onlyWithReviews: onlyWithReviews,
        courseName: courseName.trim(),
        courseCode: courseCode.trim(),
        teacherName: teacherName.trim(),
        teacherCode: teacherCode.trim(),
        campus: campus.trim(),
        faculty: faculty.trim(),
      ),
    );
    unawaited(refresh());
  }

  void resetAdvancedFilters() {
    final value = state.value ?? const CatalogState();
    state = AsyncData(
      value.copyWith(
        selectedDepartments: const [],
        onlyWithReviews: false,
        courseName: '',
        courseCode: '',
        teacherName: '',
        teacherCode: '',
        campus: '',
        faculty: '',
      ),
    );
    unawaited(refresh());
  }

  /// When [totalCount] is known (from an `includeTotal` response), derive
  /// [hasMore] from how many items we have vs the total.  The backend
  /// incorrectly returns `hasMore: false` when `includeTotal` is true, so
  /// we cannot trust the API value in that case.
  static bool _computeHasMore(
    int loadedCount,
    int? totalCount,
    bool apiHasMore,
  ) {
    if (totalCount != null) return loadedCount < totalCount;
    return apiHasMore;
  }

  Future<CatalogState> _loadPage(CatalogState base, {required int page}) async {
    final response = await _courseRepository.getCourses(
      query: base.searchText,
      departments: base.selectedDepartments,
      onlyWithReviews: base.onlyWithReviews,
      courseName: base.courseName.trim(),
      courseCode: base.courseCode.trim(),
      teacherName: base.teacherName.trim(),
      teacherCode: base.teacherCode.trim(),
      campus: base.campus.trim(),
      faculty: base.faculty.trim(),
      page: page,
      includeTotal: true,
      cancelToken: _cancelToken,
    );
    return base.copyWith(
      courses: response.data,
      hasMore: response.hasMore,
      totalCount: response.total,
      isLoadingMore: false,
    );
  }
}
