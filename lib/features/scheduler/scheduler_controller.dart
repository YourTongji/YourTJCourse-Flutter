import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cancel_token_scope.dart';
import 'scheduler_models.dart';
import 'scheduler_repository.dart';

final schedulerControllerProvider =
    AsyncNotifierProvider.autoDispose<SchedulerController, SchedulerState>(
      SchedulerController.new,
    );

class SchedulerState {
  const SchedulerState({
    this.calendars = const [],
    this.grades = const [],
    this.majors = const [],
    this.majorCourses = const [],
    this.searchCourses = const [],
    this.timeCourses = const [],
    this.optionalTypes = const [],
    this.selected = const [],
    this.selectedCalendarId,
    this.selectedGrade,
    this.selectedMajorCode,
    this.searchText = '',
    this.notice,
    this.isBusy = false,
    this.isMajorOptionsLoading = false,
    this.isMajorCoursesLoading = false,
  });

  final List<CalendarTerm> calendars;
  final List<int> grades;
  final List<MajorInfo> majors;
  final List<SchedulerCourse> majorCourses;
  final List<SchedulerCourse> searchCourses;
  final List<SchedulerCourse> timeCourses;
  final List<OptionalCourseType> optionalTypes;
  final List<ScheduledClass> selected;
  final int? selectedCalendarId;
  final int? selectedGrade;
  final String? selectedMajorCode;
  final String searchText;
  final String? notice;
  final bool isBusy;
  final bool isMajorOptionsLoading;
  final bool isMajorCoursesLoading;

  SchedulerState copyWith({
    List<CalendarTerm>? calendars,
    List<int>? grades,
    List<MajorInfo>? majors,
    List<SchedulerCourse>? majorCourses,
    List<SchedulerCourse>? searchCourses,
    List<SchedulerCourse>? timeCourses,
    List<OptionalCourseType>? optionalTypes,
    List<ScheduledClass>? selected,
    int? selectedCalendarId,
    int? selectedGrade,
    String? selectedMajorCode,
    String? searchText,
    String? notice,
    bool? isBusy,
    bool? isMajorOptionsLoading,
    bool? isMajorCoursesLoading,
    bool clearGrade = false,
    bool clearMajor = false,
    bool clearNotice = false,
  }) {
    return SchedulerState(
      calendars: calendars ?? this.calendars,
      grades: grades ?? this.grades,
      majors: majors ?? this.majors,
      majorCourses: majorCourses ?? this.majorCourses,
      searchCourses: searchCourses ?? this.searchCourses,
      timeCourses: timeCourses ?? this.timeCourses,
      optionalTypes: optionalTypes ?? this.optionalTypes,
      selected: selected ?? this.selected,
      selectedCalendarId: selectedCalendarId ?? this.selectedCalendarId,
      selectedGrade: clearGrade ? null : selectedGrade ?? this.selectedGrade,
      selectedMajorCode: clearMajor
          ? null
          : selectedMajorCode ?? this.selectedMajorCode,
      searchText: searchText ?? this.searchText,
      notice: clearNotice ? null : notice ?? this.notice,
      isBusy: isBusy ?? this.isBusy,
      isMajorOptionsLoading:
          isMajorOptionsLoading ?? this.isMajorOptionsLoading,
      isMajorCoursesLoading:
          isMajorCoursesLoading ?? this.isMajorCoursesLoading,
    );
  }
}

class SchedulerController extends AsyncNotifier<SchedulerState> {
  late SchedulerRepository _repository;
  late CancelToken _cancelToken;

  @override
  Future<SchedulerState> build() async {
    _repository = ref.watch(schedulerRepositoryProvider);
    _cancelToken = scopedCancelToken(ref);
    return _loadInitial();
  }

  Future<SchedulerState> _loadInitial() async {
    try {
      final calendars = await _repository.getAllCalendar(
        cancelToken: _cancelToken,
      );
      if (calendars.isEmpty) {
        return const SchedulerState();
      }
      final calendarId = calendars.first.calendarId;
      final results = await Future.wait([
        _repository.findGradeByCalendarId(
          calendarId,
          cancelToken: _cancelToken,
        ),
        _repository.findOptionalCourseType(
          calendarId,
          cancelToken: _cancelToken,
        ),
      ]);
      final grades = results[0] as List<int>;
      final selectedGrade = grades.firstOrNull;
      final majors = selectedGrade == null
          ? const <MajorInfo>[]
          : await _repository.findMajorByGrade(
              calendarId: calendarId,
              grade: selectedGrade,
              cancelToken: _cancelToken,
            );
      final selectedMajorCode = majors.firstOrNull?.code;
      final majorCourses = selectedGrade == null || selectedMajorCode == null
          ? const <SchedulerCourse>[]
          : await _repository.findCourseByMajor(
              calendarId: calendarId,
              grade: selectedGrade,
              code: selectedMajorCode,
              cancelToken: _cancelToken,
            );
      return SchedulerState(
        calendars: calendars,
        selectedCalendarId: calendarId,
        grades: grades,
        selectedGrade: selectedGrade,
        majors: majors,
        selectedMajorCode: selectedMajorCode,
        majorCourses: majorCourses,
        optionalTypes: results[1] as List<OptionalCourseType>,
      );
    } catch (error) {
      if (isRequestCancellation(error)) {
        return state.value ?? const SchedulerState();
      }
      return (state.value ?? const SchedulerState()).copyWith(
        notice: error.toString(),
      );
    }
  }

  Future<void> selectCalendar(int calendarId) async {
    final current = state.value ?? const SchedulerState();
    state = AsyncData(
      current.copyWith(
        selectedCalendarId: calendarId,
        grades: const [],
        majors: const [],
        majorCourses: const [],
        timeCourses: const [],
        searchCourses: const [],
        clearGrade: true,
        clearMajor: true,
        isBusy: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final results = await Future.wait([
        _repository.findGradeByCalendarId(
          calendarId,
          cancelToken: _cancelToken,
        ),
        _repository.findOptionalCourseType(
          calendarId,
          cancelToken: _cancelToken,
        ),
      ]);
      final latest = state.value ?? current;
      final grades = results[0] as List<int>;
      final selectedGrade = grades.firstOrNull;
      final majors = selectedGrade == null
          ? const <MajorInfo>[]
          : await _repository.findMajorByGrade(
              calendarId: calendarId,
              grade: selectedGrade,
              cancelToken: _cancelToken,
            );
      final selectedMajorCode = majors.firstOrNull?.code;
      final majorCourses = selectedGrade == null || selectedMajorCode == null
          ? const <SchedulerCourse>[]
          : await _repository.findCourseByMajor(
              calendarId: calendarId,
              grade: selectedGrade,
              code: selectedMajorCode,
              cancelToken: _cancelToken,
            );
      state = AsyncData(
        latest.copyWith(
          grades: grades,
          selectedGrade: selectedGrade,
          majors: majors,
          selectedMajorCode: selectedMajorCode,
          majorCourses: majorCourses,
          optionalTypes: results[1] as List<OptionalCourseType>,
          isBusy: false,
        ),
      );
    });
  }

  Future<void> selectGrade(int grade) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return;
    state = AsyncData(
      current.copyWith(
        selectedGrade: grade,
        selectedMajorCode: '',
        majors: const [],
        majorCourses: const [],
        clearMajor: true,
        isBusy: true,
        isMajorOptionsLoading: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final majors = await _repository.findMajorByGrade(
        calendarId: calendarId,
        grade: grade,
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      final selectedMajorCode = majors.firstOrNull?.code;
      final majorCourses = selectedMajorCode == null
          ? const <SchedulerCourse>[]
          : await _repository.findCourseByMajor(
              calendarId: calendarId,
              grade: grade,
              code: selectedMajorCode,
              cancelToken: _cancelToken,
            );
      state = AsyncData(
        latest.copyWith(
          majors: majors,
          selectedMajorCode: selectedMajorCode,
          majorCourses: majorCourses,
          isBusy: false,
          isMajorOptionsLoading: false,
        ),
      );
    });
  }

  void selectMajor(String code) {
    final current = state.value ?? const SchedulerState();
    state = AsyncData(
      current.copyWith(
        selectedMajorCode: code,
        majorCourses: const [],
        clearNotice: true,
      ),
    );
  }

  Future<void> loadMajorCourses() async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    final grade = current.selectedGrade;
    final code = current.selectedMajorCode;
    if (calendarId == null || grade == null || code == null || code.isEmpty) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        majorCourses: const [],
        searchCourses: const [],
        timeCourses: const [],
        isBusy: true,
        isMajorCoursesLoading: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final courses = await _repository.findCourseByMajor(
        calendarId: calendarId,
        grade: grade,
        code: code,
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          majorCourses: courses,
          isBusy: false,
          isMajorCoursesLoading: false,
        ),
      );
    });
  }

  Future<void> search({
    String courseName = '',
    String courseCode = '',
    String teacherName = '',
  }) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return;
    final keyword = [
      courseName,
      courseCode,
      teacherName,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).join(' / ');
    state = AsyncData(
      current.copyWith(
        searchText: keyword,
        majorCourses: const [],
        searchCourses: const [],
        timeCourses: const [],
        isBusy: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final courses = await _repository.findCourseBySearch(
        calendarId: calendarId,
        courseName: courseName.trim().isEmpty ? null : courseName.trim(),
        courseCode: courseCode.trim().isEmpty ? null : courseCode.trim(),
        teacherName: teacherName.trim().isEmpty ? null : teacherName.trim(),
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(searchCourses: courses, isBusy: false));
    });
  }

  Future<void> findByTime({required int day, required int section}) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return;
    state = AsyncData(
      current.copyWith(
        majorCourses: const [],
        searchCourses: const [],
        timeCourses: const [],
        isBusy: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final courses = await _repository.findCourseByTime(
        calendarId: calendarId,
        day: day,
        section: section,
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(timeCourses: courses, isBusy: false));
    });
  }

  void addClass(SchedulerCourse course, SchedulerClass classInfo) {
    final current = state.value ?? const SchedulerState();
    final collision = _findCollision(current.selected, classInfo);
    if (collision != null) {
      state = AsyncData(
        current.copyWith(notice: '与 ${collision.course.courseName} 时间冲突'),
      );
      return;
    }
    final selected = [
      ...current.selected.where(
        (item) => !_isSameBaseCourse(item.classInfo.code, classInfo.code),
      ),
      ScheduledClass(course: course, classInfo: classInfo),
    ];
    state = AsyncData(current.copyWith(selected: selected, notice: '已加入模拟课表'));
  }

  void removeClass(String code) {
    final current = state.value ?? const SchedulerState();
    state = AsyncData(
      current.copyWith(
        selected: current.selected
            .where((item) => !_isSameBaseCourse(item.classInfo.code, code))
            .toList(growable: false),
        clearNotice: true,
      ),
    );
  }

  ScheduledClass? classAt(int day, int slot) {
    final current = state.value;
    if (current == null) return null;
    for (final item in current.selected) {
      for (final arrangement in item.classInfo.arrangements) {
        if (arrangement.occupyDay == day &&
            arrangement.occupyTime.contains(slot)) {
          return item;
        }
      }
    }
    return null;
  }

  ScheduledClass? _findCollision(
    List<ScheduledClass> selected,
    SchedulerClass candidate,
  ) {
    for (final existing in selected) {
      if (_isSameBaseCourse(existing.classInfo.code, candidate.code)) continue;
      for (final left in existing.classInfo.arrangements) {
        for (final right in candidate.arrangements) {
          final sameDay = left.occupyDay == right.occupyDay;
          final sameSlot = left.occupyTime.any(right.occupyTime.contains);
          final sameWeek = left.occupyWeek.any(right.occupyWeek.contains);
          if (sameDay && sameSlot && sameWeek) return existing;
        }
      }
    }
    return null;
  }

  bool _isSameBaseCourse(String left, String right) {
    String strip(String code) {
      final dot = code.lastIndexOf('.');
      return dot > 0 ? code.substring(0, dot) : code;
    }

    return strip(left) == strip(right);
  }

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } catch (error) {
      if (isRequestCancellation(error)) {
        final current = state.value ?? const SchedulerState();
        state = AsyncData(
          current.copyWith(
            isBusy: false,
            isMajorOptionsLoading: false,
            isMajorCoursesLoading: false,
          ),
        );
        return;
      }
      final current = state.value ?? const SchedulerState();
      state = AsyncData(
        current.copyWith(
          isBusy: false,
          isMajorOptionsLoading: false,
          isMajorCoursesLoading: false,
          notice: error.toString(),
        ),
      );
    }
  }
}
