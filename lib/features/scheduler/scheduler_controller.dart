import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.optionalCourses = const [],
    this.searchCourses = const [],
    this.timeCourses = const [],
    this.optionalTypes = const [],
    this.selectedOptionalTypeIds = const {},
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
  final List<SchedulerCourse> optionalCourses;
  final List<SchedulerCourse> searchCourses;
  final List<SchedulerCourse> timeCourses;
  final List<OptionalCourseType> optionalTypes;
  final Set<int> selectedOptionalTypeIds;
  final List<ScheduledClass> selected;
  final int? selectedCalendarId;
  final int? selectedGrade;
  final String? selectedMajorCode;
  final String searchText;
  final String? notice;
  final bool isBusy;
  final bool isMajorOptionsLoading;
  final bool isMajorCoursesLoading;

  List<SchedulerTimetableEntry> get timetableEntries {
    return selected
        .expand(SchedulerTimetableEntry.fromClass)
        .toList(growable: false);
  }

  List<ScheduledClass> get unscheduledSelected {
    return selected
        .where((item) => SchedulerTimetableEntry.fromClass(item).isEmpty)
        .toList(growable: false);
  }

  SchedulerState copyWith({
    List<CalendarTerm>? calendars,
    List<int>? grades,
    List<MajorInfo>? majors,
    List<SchedulerCourse>? majorCourses,
    List<SchedulerCourse>? optionalCourses,
    List<SchedulerCourse>? searchCourses,
    List<SchedulerCourse>? timeCourses,
    List<OptionalCourseType>? optionalTypes,
    Set<int>? selectedOptionalTypeIds,
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
      optionalCourses: optionalCourses ?? this.optionalCourses,
      searchCourses: searchCourses ?? this.searchCourses,
      timeCourses: timeCourses ?? this.timeCourses,
      optionalTypes: optionalTypes ?? this.optionalTypes,
      selectedOptionalTypeIds:
          selectedOptionalTypeIds ?? this.selectedOptionalTypeIds,
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

class SchedulerTimetableEntry {
  const SchedulerTimetableEntry({
    required this.day,
    required this.slot,
    required this.item,
    required this.arrangement,
  });

  factory SchedulerTimetableEntry.fromArrangement({
    required ScheduledClass item,
    required ArrangementInfo arrangement,
    required int slot,
  }) {
    return SchedulerTimetableEntry(
      day: arrangement.occupyDay,
      slot: slot,
      item: item,
      arrangement: arrangement,
    );
  }

  static List<SchedulerTimetableEntry> fromClass(ScheduledClass item) {
    final entries = <SchedulerTimetableEntry>[];
    for (final arrangement in item.classInfo.arrangements) {
      final day = arrangement.occupyDay;
      if (day < 1 || day > 7) continue;
      for (final slot in arrangement.occupyTime) {
        if (slot < 1 || slot > 12) continue;
        entries.add(
          SchedulerTimetableEntry.fromArrangement(
            item: item,
            arrangement: arrangement,
            slot: slot,
          ),
        );
      }
    }
    return entries;
  }

  final int day;
  final int slot;
  final ScheduledClass item;
  final ArrangementInfo arrangement;

  bool occupies(int targetDay, int targetSlot) {
    return day == targetDay && slot == targetSlot;
  }
}

class SchedulerController extends AsyncNotifier<SchedulerState> {
  static const _selectedStorageKey = 'de.yourtj.course.scheduler.selected';

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
      final selected = await _restoreSelectedClasses(calendarId);
      return SchedulerState(
        calendars: calendars,
        selectedCalendarId: calendarId,
        grades: grades,
        optionalTypes: results[1] as List<OptionalCourseType>,
        selected: selected,
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
        optionalCourses: const [],
        timeCourses: const [],
        searchCourses: const [],
        selectedOptionalTypeIds: const {},
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
      state = AsyncData(
        latest.copyWith(
          grades: grades,
          majors: const [],
          optionalTypes: results[1] as List<OptionalCourseType>,
          selectedOptionalTypeIds: const {},
          isBusy: false,
          clearGrade: true,
          clearMajor: true,
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
        optionalCourses: const [],
        selectedOptionalTypeIds: const {},
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
      state = AsyncData(
        latest.copyWith(
          majors: majors,
          clearMajor: true,
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
        optionalCourses: const [],
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
        optionalCourses: const [],
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

  Future<void> loadOptionalCourses() async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null || current.selectedOptionalTypeIds.isEmpty) return;
    state = AsyncData(
      current.copyWith(
        optionalCourses: const [],
        searchCourses: const [],
        timeCourses: const [],
        isBusy: true,
        clearNotice: true,
      ),
    );
    await _guard(() async {
      final courses = await _repository.findCourseByNatureId(
        calendarId: calendarId,
        ids: current.selectedOptionalTypeIds.toList(growable: false),
        cancelToken: _cancelToken,
      );
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(optionalCourses: courses, isBusy: false),
      );
    });
  }

  void toggleOptionalType(List<int> courseLabelIds) {
    final current = state.value ?? const SchedulerState();
    final ids = courseLabelIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) return;
    final selected = {...current.selectedOptionalTypeIds};
    final shouldRemove = ids.every(selected.contains);
    if (shouldRemove) {
      selected.removeAll(ids);
    } else {
      selected.addAll(ids);
    }
    state = AsyncData(
      current.copyWith(
        selectedOptionalTypeIds: selected,
        optionalCourses: const [],
        clearNotice: true,
      ),
    );
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
        optionalCourses: const [],
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
        optionalCourses: const [],
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

  Future<SchedulerCourse> loadCourseClasses(SchedulerCourse course) async {
    if (course.classes.isNotEmpty) return course;
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return course;
    final hydrated = (await _repository.hydrateCourseClasses(
      calendarId: calendarId,
      course: course,
      cancelToken: _cancelToken,
    )).first;
    _replaceCourseInResults(hydrated);
    return hydrated;
  }

  void _replaceCourseInResults(SchedulerCourse course) {
    final current = state.value ?? const SchedulerState();
    List<SchedulerCourse> replace(List<SchedulerCourse> courses) {
      return courses
          .map((item) => item.courseCode == course.courseCode ? course : item)
          .toList(growable: false);
    }

    state = AsyncData(
      current.copyWith(
        majorCourses: replace(current.majorCourses),
        optionalCourses: replace(current.optionalCourses),
        searchCourses: replace(current.searchCourses),
        timeCourses: replace(current.timeCourses),
      ),
    );
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
    _persistSelectedClasses(selected);
  }

  Future<void> saveSelectedClasses() async {
    final current = state.value ?? const SchedulerState();
    await _persistSelectedClasses(current.selected);
    state = AsyncData(current.copyWith(notice: '已保存模拟课表'));
  }

  void removeClass(String code) {
    final current = state.value ?? const SchedulerState();
    final selected = current.selected
        .where((item) => !_isSameBaseCourse(item.classInfo.code, code))
        .toList(growable: false);
    state = AsyncData(current.copyWith(selected: selected, clearNotice: true));
    _persistSelectedClasses(selected);
  }

  void clearSelectedClasses() {
    final current = state.value ?? const SchedulerState();
    state = AsyncData(current.copyWith(selected: const [], clearNotice: true));
    _persistSelectedClasses(const []);
  }

  ScheduledClass? classAt(int day, int slot) {
    final current = state.value;
    if (current == null) return null;
    for (final entry in current.timetableEntries) {
      if (entry.occupies(day, slot)) return entry.item;
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
          final sameWeek =
              left.occupyWeek.isEmpty ||
              right.occupyWeek.isEmpty ||
              left.occupyWeek.any(right.occupyWeek.contains);
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

  Future<List<ScheduledClass>> _restoreSelectedClasses(int calendarId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_selectedStorageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final selected = decoded
          .map(ScheduledClass.fromJson)
          .toList(growable: false);
      return _rehydrateSelectedClasses(calendarId, selected);
    } catch (_) {
      return const [];
    }
  }

  Future<List<ScheduledClass>> _rehydrateSelectedClasses(
    int calendarId,
    List<ScheduledClass> selected,
  ) async {
    var changed = false;
    final hydrated = <ScheduledClass>[];
    for (final item in selected) {
      if (_hasUsableSchedule(item.classInfo)) {
        hydrated.add(item);
        continue;
      }
      final localClass = _matchingClass(item.course.classes, item.classInfo);
      if (localClass != null && _hasUsableSchedule(localClass)) {
        hydrated.add(
          ScheduledClass(course: item.course, classInfo: localClass),
        );
        changed = true;
        continue;
      }
      try {
        final remoteClasses = await _repository.findCourseDetailByCode(
          calendarId: calendarId,
          courseCode: item.course.courseCode,
          cancelToken: _cancelToken,
        );
        final remoteClass = _matchingClass(remoteClasses, item.classInfo);
        if (remoteClass != null && _hasUsableSchedule(remoteClass)) {
          hydrated.add(
            ScheduledClass(
              course: item.course.copyWith(classes: remoteClasses),
              classInfo: remoteClass,
            ),
          );
          changed = true;
          continue;
        }
      } catch (_) {
        // 恢复本地课表时不要因为单门课程补详情失败而丢掉其他已选记录。
      }
      hydrated.add(item);
    }
    if (changed) await _persistSelectedClasses(hydrated);
    return hydrated;
  }

  SchedulerClass? _matchingClass(
    List<SchedulerClass> classes,
    SchedulerClass target,
  ) {
    for (final classInfo in classes) {
      if (classInfo.code == target.code) return classInfo;
    }
    return null;
  }

  bool _hasUsableSchedule(SchedulerClass classInfo) {
    return classInfo.arrangements.any(
      (arrangement) =>
          arrangement.occupyDay >= 1 &&
          arrangement.occupyDay <= 7 &&
          arrangement.occupyTime.isNotEmpty,
    );
  }

  Future<void> _persistSelectedClasses(List<ScheduledClass> selected) async {
    final preferences = await SharedPreferences.getInstance();
    if (selected.isEmpty) {
      await preferences.remove(_selectedStorageKey);
      return;
    }
    final data = selected.map((item) => item.toJson()).toList(growable: false);
    await preferences.setString(_selectedStorageKey, jsonEncode(data));
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
