import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourtjcourse_flutter/core/network/api_client.dart';
import 'package:yourtjcourse_flutter/domain/models/course.dart';
import 'package:yourtjcourse_flutter/domain/models/paginated_response.dart';
import 'package:yourtjcourse_flutter/domain/repositories/course_repository.dart';
import 'package:yourtjcourse_flutter/domain/repositories/settings_repository.dart';
import 'package:yourtjcourse_flutter/features/catalog/catalog_controller.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_controller.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_models.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalog controller can rebuild without late final errors', () async {
    final container = ProviderContainer(
      overrides: [
        courseRepositoryProvider.overrideWithValue(_FakeCourseRepository()),
        settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(catalogControllerProvider.future);
    container.invalidate(catalogControllerProvider);
    final second = await container.read(catalogControllerProvider.future);

    expect(first.courses.single.name, '高等数学');
    expect(second.courses.single.name, '高等数学');
  });

  test('scheduler controller can rebuild without late final errors', () async {
    final container = ProviderContainer(
      overrides: [
        schedulerRepositoryProvider.overrideWithValue(
          _FakeSchedulerRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final first = await container.read(schedulerControllerProvider.future);
    container.invalidate(schedulerControllerProvider);
    final second = await container.read(schedulerControllerProvider.future);

    expect(first.selectedCalendarId, 202401);
    expect(second.selectedCalendarId, 202401);
    expect(second.grades, [2024]);
    expect(second.selectedGrade, isNull);
    expect(second.selectedMajorCode, isNull);
    expect(second.majors, isEmpty);
    expect(second.majorCourses, isEmpty);
  });

  test(
    'scheduler controller loads major candidates after user selection',
    () async {
      final container = ProviderContainer(
        overrides: [
          schedulerRepositoryProvider.overrideWithValue(
            _FakeSchedulerRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(schedulerControllerProvider.future);
      final controller = container.read(schedulerControllerProvider.notifier);
      await controller.selectGrade(2024);
      controller.selectMajor('080901');
      await controller.loadMajorCourses();
      final state = container.read(schedulerControllerProvider).value!;

      expect(state.selectedGrade, 2024);
      expect(state.selectedMajorCode, '080901');
      expect(state.majors.single.name, '计算机科学与技术');
      expect(state.majorCourses.single.courseName, '数据结构');
    },
  );

  test('scheduler controller restores selected simulation classes', () async {
    final saved = ScheduledClass(
      course: _FakeSchedulerRepository.sampleCourse,
      classInfo: _FakeSchedulerRepository.sampleCourse.classes.single,
    );
    SharedPreferences.setMockInitialValues({
      'flutter.de.yourtj.course.scheduler.selected': jsonEncode([
        saved.toJson(),
      ]),
    });
    final container = ProviderContainer(
      overrides: [
        schedulerRepositoryProvider.overrideWithValue(
          _FakeSchedulerRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(schedulerControllerProvider.future);

    expect(state.selected.single.course.courseName, '数据结构');
    expect(state.selected.single.classInfo.code, 'COMP001.01');
  });

  test(
    'scheduler controller rehydrates saved class for timetable placement',
    () async {
      final saved = ScheduledClass(
        course: _FakeSchedulerRepository.roughSearchCourse,
        classInfo: const SchedulerClass(
          code: 'PHYS001.01',
          campus: '四平路',
          teachers: [TeacherInfo(teacherName: '王老师', teacherCode: 'T002')],
          teachingLanguage: '中文',
          arrangements: [],
        ),
      );
      SharedPreferences.setMockInitialValues({
        'flutter.de.yourtj.course.scheduler.selected': jsonEncode([
          saved.toJson(),
        ]),
      });
      final container = ProviderContainer(
        overrides: [
          schedulerRepositoryProvider.overrideWithValue(
            _FakeSchedulerRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(schedulerControllerProvider.future);
      final controller = container.read(schedulerControllerProvider.notifier);
      final state = container.read(schedulerControllerProvider).value!;

      expect(state.selected.single.occupies(3, 5), isTrue);
      expect(controller.classAt(3, 5)?.course.courseName, '大学物理');
    },
  );

  test(
    'scheduler controller hydrates rough course before adding class',
    () async {
      final container = ProviderContainer(
        overrides: [
          schedulerRepositoryProvider.overrideWithValue(
            _FakeSchedulerRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(schedulerControllerProvider.future);
      final controller = container.read(schedulerControllerProvider.notifier);
      await controller.search(courseName: '大学物理');
      final searched = container.read(schedulerControllerProvider).value!;

      expect(searched.searchCourses.single.classes, isEmpty);

      final hydrated = await controller.loadCourseClasses(
        searched.searchCourses.single,
      );
      controller.addClass(hydrated, hydrated.classes.single);
      final state = container.read(schedulerControllerProvider).value!;

      expect(hydrated.classes.single.code, 'PHYS001.01');
      expect(state.searchCourses.single.classes.single.code, 'PHYS001.01');
      expect(state.selected.single.course.courseName, '大学物理');
      expect(state.timetableEntries, hasLength(2));
      expect(state.timetableEntries.map((entry) => entry.day), [3, 3]);
      expect(state.timetableEntries.map((entry) => entry.slot), [5, 6]);
      expect(controller.classAt(3, 5)?.course.courseName, '大学物理');
    },
  );

  test('scheduler controller loads optional course candidates', () async {
    final container = ProviderContainer(
      overrides: [
        schedulerRepositoryProvider.overrideWithValue(
          _FakeSchedulerRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(schedulerControllerProvider.future);
    final controller = container.read(schedulerControllerProvider.notifier);
    controller.toggleOptionalType([1]);
    await controller.loadOptionalCourses();
    final state = container.read(schedulerControllerProvider).value!;

    expect(state.selectedOptionalTypeIds, {1});
    expect(state.optionalCourses.single.courseName, '艺术导论');
    expect(state.optionalCourses.single.courseNature, ['通识选修']);
  });
}

class _FakeCourseRepository extends CourseRepository {
  _FakeCourseRepository() : super(ApiClient(Dio()));

  @override
  Future<PaginatedResponse<Course>> getCourses({
    String? query,
    List<String>? departments,
    bool onlyWithReviews = false,
    int page = 1,
    int limit = 20,
    bool includeTotal = false,
    CancelToken? cancelToken,
  }) async {
    return const PaginatedResponse(
      data: [
        Course(
          id: 1,
          code: 'MATH001',
          name: '高等数学',
          rating: 4.5,
          reviewCount: 3,
          isLegacy: 0,
          teacherName: '张老师',
          department: '数学科学学院',
          credit: 5,
          semesters: ['2024-2025-1'],
        ),
      ],
      hasMore: false,
      total: 1,
    );
  }
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository() : super(ApiClient(Dio()));

  @override
  Future<List<String>> getDepartments({CancelToken? cancelToken}) async {
    return const ['数学科学学院'];
  }
}

class _FakeSchedulerRepository extends SchedulerRepository {
  _FakeSchedulerRepository() : super(ApiClient(Dio()));

  static const sampleCourse = SchedulerCourse(
    courseCode: 'COMP001',
    courseName: '数据结构',
    credit: 3,
    faculty: '电子与信息工程学院',
    courseNature: ['专业基础课'],
    campus: ['嘉定'],
    classes: [
      SchedulerClass(
        code: 'COMP001.01',
        campus: '嘉定',
        teachers: [TeacherInfo(teacherName: '李老师', teacherCode: 'T001')],
        teachingLanguage: '中文',
        arrangements: [
          ArrangementInfo(
            arrangementText: '周一 1-2 节',
            occupyDay: 1,
            occupyTime: [1, 2],
            occupyWeek: [1, 2],
            occupyRoom: 'J101',
            teacherAndCode: '李老师 T001',
          ),
        ],
      ),
    ],
  );

  static const roughSearchCourse = SchedulerCourse(
    courseCode: 'PHYS001',
    courseName: '大学物理',
    credit: 3,
    faculty: '物理科学与工程学院',
    courseNature: ['公共基础课'],
    campus: ['四平路'],
    classes: [],
  );

  static const searchClass = SchedulerClass(
    code: 'PHYS001.01',
    campus: '四平路',
    teachers: [TeacherInfo(teacherName: '王老师', teacherCode: 'T002')],
    teachingLanguage: '中文',
    arrangements: [
      ArrangementInfo(
        arrangementText: '周三 5-6 节',
        occupyDay: 3,
        occupyTime: [5, 6],
        occupyWeek: [1, 2],
        occupyRoom: 'H101',
        teacherAndCode: '王老师 T002',
      ),
    ],
  );

  static const optionalCourse = SchedulerCourse(
    courseCode: 'ART001',
    courseName: '艺术导论',
    credit: 2,
    faculty: '艺术与传媒学院',
    courseNature: ['通识选修'],
    campus: ['四平路'],
    classes: [],
  );

  @override
  Future<List<CalendarTerm>> getAllCalendar({CancelToken? cancelToken}) async {
    return const [
      CalendarTerm(calendarId: 202401, calendarName: '2024-2025 学年第一学期'),
    ];
  }

  @override
  Future<List<int>> findGradeByCalendarId(
    int calendarId, {
    CancelToken? cancelToken,
  }) async {
    return const [2024];
  }

  @override
  Future<List<MajorInfo>> findMajorByGrade({
    required int calendarId,
    required int grade,
    CancelToken? cancelToken,
  }) async {
    return const [MajorInfo(code: '080901', name: '计算机科学与技术')];
  }

  @override
  Future<List<SchedulerCourse>> findCourseByMajor({
    required int calendarId,
    required int grade,
    required String code,
    CancelToken? cancelToken,
  }) async {
    return const [sampleCourse];
  }

  @override
  Future<List<SchedulerCourse>> findCourseBySearch({
    required int calendarId,
    String? courseName,
    String? courseCode,
    String? teacherName,
    CancelToken? cancelToken,
  }) async {
    return const [roughSearchCourse];
  }

  @override
  Future<List<SchedulerClass>> findCourseDetailByCode({
    required int calendarId,
    required String courseCode,
    CancelToken? cancelToken,
  }) async {
    return const [searchClass];
  }

  @override
  Future<List<OptionalCourseType>> findOptionalCourseType(
    int calendarId, {
    CancelToken? cancelToken,
  }) async {
    return const [
      OptionalCourseType(courseLabelId: 1, courseLabelName: '通识选修'),
    ];
  }

  @override
  Future<List<SchedulerCourse>> findCourseByNatureId({
    required int calendarId,
    required List<int> ids,
    CancelToken? cancelToken,
  }) async {
    return const [optionalCourse];
  }
}
