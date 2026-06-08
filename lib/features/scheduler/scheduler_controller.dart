import 'dart:async';
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
    this.courseChanges = const [],
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
  final List<CourseChange> courseChanges;
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
    List<CourseChange>? courseChanges,
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
      courseChanges: courseChanges ?? this.courseChanges,
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
  static const _calendarKey = 'de.yourtj.course.scheduler.calendarId';
  static const _gradeKey = 'de.yourtj.course.scheduler.grade';
  static const _majorKey = 'de.yourtj.course.scheduler.majorCode';

  late SchedulerRepository _repository;
  late CancelToken _cancelToken;

  /// Cache for class review info, keyed by class code.
  final Map<String, SchedulerClassReviewInfo> reviewCache = {};

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

      // Restore persisted selections.
      final preferences = await SharedPreferences.getInstance();
      final savedCalendarId = preferences.getInt(_calendarKey);
      final savedGrade = preferences.getInt(_gradeKey);
      final savedMajorCode = preferences.getString(_majorKey);
      final hasSaved = savedCalendarId != null &&
          savedGrade != null &&
          savedMajorCode != null &&
          savedMajorCode.isNotEmpty;

      final targetCalendarId =
          (hasSaved && calendars.any((c) => c.calendarId == savedCalendarId))
              ? savedCalendarId
              : calendarId;

      final results = await Future.wait([
        _repository.findGradeByCalendarId(
          targetCalendarId,
          cancelToken: _cancelToken,
        ),
        _repository.findOptionalCourseType(
          targetCalendarId,
          cancelToken: _cancelToken,
        ),
      ]);
      final grades = results[0] as List<int>;
      final selected = await _restoreSelectedClasses(targetCalendarId);

      var state = SchedulerState(
        calendars: calendars,
        selectedCalendarId: targetCalendarId,
        grades: grades,
        optionalTypes: results[1] as List<OptionalCourseType>,
        selected: selected,
      );

      // Auto-load major courses when returning user has saved selections.
      if (hasSaved && grades.contains(savedGrade)) {
        final code = savedMajorCode;
        final majors = await _repository.findMajorByGrade(
          calendarId: targetCalendarId,
          grade: savedGrade,
          cancelToken: _cancelToken,
        );
        final matchedMajor = majors.where((m) => m.code == code).firstOrNull;
        if (matchedMajor != null) {
          state = state.copyWith(
            selectedGrade: savedGrade,
            selectedMajorCode: code,
            majors: majors,
          );
          final courses = await _repository.findCourseByMajor(
            calendarId: targetCalendarId,
            grade: savedGrade,
            code: code,
            cancelToken: _cancelToken,
          );
          state = state.copyWith(
            majorCourses: courses,
            isMajorCoursesLoading: false,
          );
        }
      }

      return state;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calendarKey, calendarId);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gradeKey, grade);
    await prefs.remove(_majorKey);
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
    unawaited(_persistMajorSelection(code));
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

  Future<List<SchedulerCourse>> findCoursesAtTimeForReplacement({
    required int day,
    required int section,
  }) async {
    final current = state.value ?? const SchedulerState();
    final calendarId = current.selectedCalendarId;
    if (calendarId == null) return const [];
    return _repository.findCourseByTime(
      calendarId: calendarId,
      day: day,
      section: section,
      cancelToken: _cancelToken,
    );
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

  Future<SchedulerClassReviewInfo> loadClassReviewInfo(
    SchedulerCourse course,
    SchedulerClass classInfo,
  ) async {
    final cached = reviewCache[classInfo.code];
    if (cached != null) return cached;

    final teacher = classInfo.teachers.firstOrNull;
    final info = await _repository.getClassReviewInfo(
      courseCode: course.courseCode,
      teacherCode: teacher?.teacherCode,
      teacherName: teacher?.teacherName,
      cancelToken: _cancelToken,
    );
    reviewCache[classInfo.code] = info;
    return info;
  }

  /// Pre-load review info for all classes of [course] into the cache.
  Future<void> preloadCourseReviews(SchedulerCourse course) async {
    await Future.wait(
      course.classes.map((classInfo) async {
        if (!reviewCache.containsKey(classInfo.code)) {
          try {
            final teacher = classInfo.teachers.firstOrNull;
            final info = await _repository.getClassReviewInfo(
              courseCode: course.courseCode,
              teacherCode: teacher?.teacherCode,
              teacherName: teacher?.teacherName,
              cancelToken: _cancelToken,
            );
            reviewCache[classInfo.code] = info;
          } catch (_) {
            // Silently skip failed loads.
          }
        }
      }),
    );
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
    unawaited(_updateSnapshotsAndSync());
  }

  void replaceClass({
    required String replacingCode,
    required SchedulerCourse course,
    required SchedulerClass classInfo,
  }) {
    final current = state.value ?? const SchedulerState();
    final selectedWithoutCurrent = current.selected
        .where((item) => !_isSameBaseCourse(item.classInfo.code, replacingCode))
        .toList(growable: false);
    final collision = _findCollision(selectedWithoutCurrent, classInfo);
    if (collision != null) {
      state = AsyncData(
        current.copyWith(notice: '与 ${collision.course.courseName} 时间冲突'),
      );
      return;
    }
    final selected = [
      ...selectedWithoutCurrent,
      ScheduledClass(course: course, classInfo: classInfo),
    ];
    state = AsyncData(current.copyWith(selected: selected, notice: '已替换模拟课表'));
    _persistSelectedClasses(selected);
    unawaited(_updateSnapshotsAndSync());
  }

  Future<void> saveSelectedClasses() async {
    final current = state.value ?? const SchedulerState();
    await _persistSelectedClasses(current.selected);
    // Also persist the current grade/major selection.
    final prefs = await SharedPreferences.getInstance();
    if (current.selectedGrade != null) {
      await prefs.setInt(_gradeKey, current.selectedGrade!);
    }
    if (current.selectedMajorCode != null &&
        current.selectedMajorCode!.isNotEmpty) {
      await prefs.setString(_majorKey, current.selectedMajorCode!);
    }
    if (current.selectedCalendarId != null) {
      await prefs.setInt(_calendarKey, current.selectedCalendarId!);
    }
    state = AsyncData(current.copyWith(notice: '已保存模拟课表'));
  }

  void removeClass(String code) {
    final current = state.value ?? const SchedulerState();
    final selected = current.selected
        .where((item) => !_isSameBaseCourse(item.classInfo.code, code))
        .toList(growable: false);
    state = AsyncData(current.copyWith(selected: selected, clearNotice: true));
    _persistSelectedClasses(selected);
    unawaited(_updateSnapshotsAndSync());
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

  Future<void> _persistMajorSelection(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_majorKey, code);
  }

  /// Returns the set of course codes that already have at least one
  /// teaching class in the current schedule.
  Set<String> scheduledCourseCodes() {
    final current = state.value;
    if (current == null) return const {};
    return current.selected.map((s) => s.course.courseCode).toSet();
  }

  int? get selectedCalendarId => state.value?.selectedCalendarId;

  /// Remove all scheduled classes for the given [courseCode] from the schedule.
  void unscheduleCourse(String courseCode) {
    final current = state.value;
    if (current == null) return;
    final remaining = current.selected
        .where((s) => s.course.courseCode != courseCode)
        .toList(growable: false);
    state = AsyncData(current.copyWith(
      selected: remaining,
      notice: '已清除「$courseCode」的排课状态',
    ));
    _persistSelectedClasses(remaining);
    unawaited(_updateSnapshotsAndSync());
  }

  // ─── Course change detection ──────────────────────────────────────

  static const _snapshotKey = 'de.yourtj.course.scheduler.snapshots';
  Timer? _syncTimer;

  /// Take a snapshot of the current schedule and persist it.
  Future<void> _saveSnapshots() async {
    final current = state.value;
    if (current == null || current.selected.isEmpty) return;
    final snapshots = current.selected
        .map(ScheduledClassSnapshot.fromScheduledClass)
        .toList(growable: false);
    final data = snapshots.map((s) => s.toJson()).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode(data));
  }

  /// Restore snapshots from storage.
  Future<List<ScheduledClassSnapshot>> _loadSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(ScheduledClassSnapshot.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Check for changes by fetching fresh data and comparing.
  Future<List<CourseChange>> checkForChanges() async {
    final current = state.value;
    if (current == null || current.selected.isEmpty) return [];

    final snapshots = await _loadSnapshots();
    if (snapshots.isEmpty) {
      // First time — just save and return.
      await _saveSnapshots();
      return [];
    }

    final changes = <CourseChange>[];
    final snapshotByCode = {
      for (final s in snapshots) s.classCode: s,
    };

    // Fetch fresh data for all selected courses.
    final courseCodes = current.selected
        .map((s) => s.course.courseCode)
        .toSet()
        .toList(growable: false);

    final freshClasses = <ScheduledClassSnapshot>[];
    for (final code in courseCodes) {
      try {
        final classes = await _repository.findCourseDetailByCode(
          calendarId: current.selectedCalendarId ?? 0,
          courseCode: code,
          cancelToken: _cancelToken,
        );
        for (final c in classes) {
          final sc = current.selected
              .where((s) => s.classInfo.code == c.code)
              .firstOrNull;
          if (sc != null) {
            freshClasses.add(
              ScheduledClassSnapshot.fromScheduledClass(
                ScheduledClass(course: sc.course, classInfo: c),
              ),
            );
          }
        }
      } catch (_) {
        // Skip failed fetches.
      }
    }

    // Compare fresh vs snapshot.
    final freshByCode = {for (final f in freshClasses) f.classCode: f};
    final allCodes = {
      ...snapshotByCode.keys,
      ...freshByCode.keys,
    };

    for (final code in allCodes) {
      final old = snapshotByCode[code];
      final fresh = freshByCode[code];
      if (old == null && fresh != null) {
        // New class appeared (unlikely but handle).
        continue;
      }
      if (old != null && fresh == null) {
        // Class disappeared — likely closed.
        changes.add(
          CourseChange(
            type: CourseChangeType.closed,
            courseCode: old.courseCode,
            courseName: old.courseName,
            detail: '教学班 $code 已关闭',
          ),
        );
        continue;
      }
      if (old != null && fresh != null) {
        final oldArr = old.arrangementTexts.toSet();
        final freshArr = fresh.arrangementTexts.toSet();
        if (oldArr != freshArr) {
          changes.add(
            CourseChange(
              type: CourseChangeType.infoChanged,
              courseCode: old.courseCode,
              courseName: old.courseName,
              detail: '教学班 $code 上课安排已变更',
              affectedCodes: [code],
            ),
          );
        }
      }
    }

    if (changes.isNotEmpty) {
      // Save new snapshots for next comparison.
      await _saveSnapshots();
      // Update state with changes.
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(courseChanges: changes));
    }

    return changes;
  }

  /// Start periodic sync (every 30 minutes).
  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      checkForChanges();
    });
  }

  /// Stop periodic sync.
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _ensureSyncOnSelection() {
    _syncTimer ??= Timer.periodic(const Duration(minutes: 30), (_) {
      checkForChanges();
    });
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

  Future<void> _updateSnapshotsAndSync() async {
    await _saveSnapshots();
    _ensureSyncOnSelection();
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
