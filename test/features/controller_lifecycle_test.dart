import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    return const [
      OptionalCourseType(courseLabelId: 1, courseLabelName: '通识选修'),
    ];
  }
}
