import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourtjcourse_flutter/core/network/api_client.dart';
import 'package:yourtjcourse_flutter/features/announcements/announcement_controller.dart';
import 'package:yourtjcourse_flutter/main.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_models.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_repository.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          announcementControllerProvider.overrideWith(() {
            return _NoAnnouncementController();
          }),
        ],
        child: const YourTJCourseApp(),
      ),
    );
    await tester.pump();

    expect(find.text('查课'), findsOneWidget);
    expect(find.text('排课'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
  });

  testWidgets('renders selected scheduler class as visible timetable pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'flutter.de.yourtj.course.scheduler.selected': jsonEncode([
        ScheduledClass(
          course: _visibleCourse,
          classInfo: _visibleClass,
        ).toJson(),
      ]),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schedulerRepositoryProvider.overrideWithValue(
            _VisualSchedulerRepository(),
          ),
        ],
        child: const MaterialApp(home: SchedulerView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('课表'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('周课表已渲染'), findsNothing);
    expect(find.text('大学物理'), findsWidgets);

    final courseCell = find.byKey(
      const ValueKey('scheduler-course-cell-3-5-PHYS001.01'),
    );
    expect(courseCell, findsOneWidget);

    final rect = tester.getRect(courseCell);
    expect(rect.width, greaterThan(40));
    expect(rect.height, greaterThan(40));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(844));

    await expectLater(
      courseCell,
      matchesGoldenFile('goldens/scheduler_course_cell.png'),
    );
  });
}

class _NoAnnouncementController extends AnnouncementController {
  @override
  Future<Never?> build() async => null;
}

const _visibleCourse = SchedulerCourse(
  courseCode: 'PHYS001',
  courseName: '大学物理',
  credit: 3,
  faculty: '物理科学与工程学院',
  courseNature: ['公共基础课'],
  campus: ['四平路'],
  classes: [_visibleClass],
);

const _visibleClass = SchedulerClass(
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

class _VisualSchedulerRepository extends SchedulerRepository {
  _VisualSchedulerRepository() : super(ApiClient(Dio()));

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
  Future<List<OptionalCourseType>> findOptionalCourseType(
    int calendarId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }
}
