import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourtjcourse_flutter/core/network/api_client.dart';
import 'package:yourtjcourse_flutter/domain/models/course_detail.dart';
import 'package:yourtjcourse_flutter/domain/models/review.dart';
import 'package:yourtjcourse_flutter/features/announcements/announcement_controller.dart';
import 'package:yourtjcourse_flutter/features/course_detail/course_detail_view.dart';
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
    expect(find.text('我的'), findsOneWidget);
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

  testWidgets('looks up courses from an empty timetable slot', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _VisualSchedulerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [schedulerRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SchedulerView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('课表'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('scheduler-cell-3-5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.lastLookupDay, 3);
    expect(repository.lastLookupSection, 3);
    expect(find.text('时间段查课 · 1'), findsOneWidget);
    expect(find.text('工程伦理'), findsOneWidget);
    expect(find.text('查询结果 · 1 门'), findsOneWidget);
  });

  testWidgets('keeps all scheduler sidebar actions visible when collapsed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
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

    await tester.tap(find.byTooltip('折叠侧栏'));
    await tester.pumpAndSettle();

    final keys = [
      const ValueKey('scheduler-sidebar-filter'),
      const ValueKey('scheduler-sidebar-candidates'),
      const ValueKey('scheduler-sidebar-selected'),
      const ValueKey('scheduler-sidebar-timetable'),
    ];

    for (final key in keys) {
      final finder = find.byKey(key);
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.width, greaterThan(40));
      expect(rect.height, greaterThan(90));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(568));
    }
  });

  testWidgets('renders review share card with web aligned content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReviewShareCard(course: _shareCourse, review: _shareReview),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('YOURTJ 选课社区'), findsOneWidget);
    expect(find.text('程序设计基础'), findsOneWidget);
    expect(find.text('内容来自 YOURTJ 选课社区'), findsOneWidget);
    expect(find.text('xk.yourtj.de'), findsOneWidget);
  });

  testWidgets('generates review share image without widget screenshot', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => renderReviewShareImage(_shareCourse, _shareReview, pixelRatio: 1),
    );

    expect(bytes, isNotNull);
    final png = bytes!;
    expect(png.length, greaterThan(1024));
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
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

  int? lastLookupDay;
  int? lastLookupSection;

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

  @override
  Future<List<SchedulerCourse>> findCourseByTime({
    required int calendarId,
    required int day,
    required int section,
    CancelToken? cancelToken,
  }) async {
    lastLookupDay = day;
    lastLookupSection = section;
    return const [_timeLookupCourse];
  }
}

const _timeLookupCourse = SchedulerCourse(
  courseCode: 'ETH001',
  courseName: '工程伦理',
  credit: 2,
  faculty: '马克思主义学院',
  courseNature: ['通识选修'],
  campus: ['四平路'],
  classes: [],
);

const _shareCourse = CourseDetail(
  id: 1,
  code: 'CS1001',
  name: '程序设计基础',
  rating: 4.6,
  reviewCount: 12,
  teacherName: '张老师',
  department: '电子与信息工程学院',
  credit: 3,
  semesters: ['2024-2025-1'],
  reviews: [_shareReview],
);

const _shareReview = Review(
  id: 42,
  sqid: 'rv42',
  courseId: 1,
  semester: '2024-2025-1',
  rating: 5,
  comment: '课堂节奏清楚，作业量适中，适合打基础。',
  createdAt: '2026-06-07T08:00:00Z',
  likeCount: 3,
  liked: false,
  reviewerName: '同济同学',
);
