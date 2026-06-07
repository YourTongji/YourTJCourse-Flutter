import 'dart:async';

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
    this.hasMore = true,
    this.isLoadingMore = false,
    this.totalCount,
  });

  final List<Course> courses;
  final List<String> departments;
  final List<String> selectedDepartments;
  final String searchText;
  final bool onlyWithReviews;
  final bool hasMore;
  final bool isLoadingMore;
  final int? totalCount;

  CatalogState copyWith({
    List<Course>? courses,
    List<String>? departments,
    List<String>? selectedDepartments,
    String? searchText,
    bool? onlyWithReviews,
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
      return CatalogState(
        departments: departments,
        courses: courses.data as List<Course>,
        hasMore: courses.hasMore as bool,
        totalCount: courses.total as int?,
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
    state = const AsyncLoading<CatalogState>();
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
        page: nextPage,
        cancelToken: _cancelToken,
      );
      _page = nextPage;
      state = AsyncData(
        value.copyWith(
          courses: [...value.courses, ...response.data],
          hasMore: response.hasMore,
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
    final value = state.value ?? const CatalogState();
    state = AsyncData(value.copyWith(searchText: text));
    _searchDebounce?.cancel();
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

  Future<CatalogState> _loadPage(CatalogState base, {required int page}) async {
    final response = await _courseRepository.getCourses(
      query: base.searchText,
      departments: base.selectedDepartments,
      onlyWithReviews: base.onlyWithReviews,
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
