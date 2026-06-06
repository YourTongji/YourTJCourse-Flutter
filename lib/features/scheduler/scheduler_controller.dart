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
    );
  }
}

class SchedulerController extends AsyncNotifier<SchedulerState> {
  late final SchedulerRepository _repository;
  late final CancelToken _cancelToken;

  @override
  Future<SchedulerState> build() async {
    _repository = ref.watch(schedulerRepositoryProvider);
    _cancelToken = scopedCancelToken(ref);
    final calendars = await _repository.getAllCalendar(
      cancelToken: _cancelToken,
    );
    if (calendars.isEmpty) return const SchedulerState();
    final calendarId = calendars.first.calendarId;
    final results = await Future.wait([
      _repository.findGradeByCalendarId(calendarId, cancelToken: _cancelToken),
      _repository.findOptionalCourseType(calendarId, cancelToken: _cancelToken),
    ]);
    return SchedulerState(
      calendars: calendars,
      selectedCalendarId: calendarId,
      grades: results[0] as List<int>,
      optionalTypes: results[1] as List<OptionalCourseType>,
    );
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
      state = AsyncData(
        latest.copyWith(
          grades: results[0] as List<int>,
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
      state = AsyncData(latest.copyWith(majors: majors, isBusy: false));
    });
  }

  Future<void> selectMajor(String code) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    final grade = current.selectedGrade;
    if (calendarId == null || grade == null) return;
    state = AsyncData(
      current.copyWith(
        selectedMajorCode: code,
        majorCourses: const [],
        isBusy: true,
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
      state = AsyncData(latest.copyWith(majorCourses: courses, isBusy: false));
    });
  }

  Future<void> search(String text, SchedulerSearchField field) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return;
    state = AsyncData(
      current.copyWith(searchText: text, isBusy: true, clearNotice: true),
    );
    await _guard(() async {
      final courses = await _repository.findCourseBySearch(
        calendarId: calendarId,
        courseName: field == SchedulerSearchField.courseName ? text : null,
        courseCode: field == SchedulerSearchField.courseCode ? text : null,
        teacherName: field == SchedulerSearchField.teacherName ? text : null,
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
    state = AsyncData(current.copyWith(isBusy: true, clearNotice: true));
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
    } catch (error, stackTrace) {
      if (error is DioException && CancelToken.isCancel(error)) return;
      final current = state.value ?? const SchedulerState();
      state = AsyncData(
        current.copyWith(isBusy: false, notice: error.toString()),
      );
      state = AsyncError<SchedulerState>(error, stackTrace);
      state = AsyncData(current.copyWith(isBusy: false));
    }
  }
}

enum SchedulerSearchField {
  courseName('课程名'),
  courseCode('课号'),
  teacherName('教师');

  const SchedulerSearchField(this.label);

  final String label;
}
