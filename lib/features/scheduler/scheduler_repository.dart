import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/json_helpers.dart';
import 'scheduler_models.dart';

final schedulerRepositoryProvider = Provider<SchedulerRepository>((ref) {
  return SchedulerRepository(ref.watch(apiClientProvider));
});

class SchedulerRepository {
  const SchedulerRepository(this._client);

  final ApiClient _client;

  Future<List<CalendarTerm>> getAllCalendar({CancelToken? cancelToken}) {
    return _client.get(
      '/api/getAllCalendar',
      cancelToken: cancelToken,
      decode: (json) => _unwrapList(json)
          .map(CalendarTerm.fromJson)
          .where((item) => item.calendarId > 0)
          .toList(growable: false),
    );
  }

  Future<List<int>> findGradeByCalendarId(
    int calendarId, {
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findGradeByCalendarId',
      body: {'calendarId': calendarId},
      cancelToken: cancelToken,
      decode: (json) {
        final map = asJsonMap(_unwrapData(json));
        final list = map['gradeList'];
        if (list is! List) return const <int>[];
        return list.map(readInt).whereType<int>().toList(growable: false);
      },
    );
  }

  Future<List<MajorInfo>> findMajorByGrade({
    required int calendarId,
    required int grade,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findMajorByGrade',
      body: {'calendarId': calendarId, 'grade': grade},
      cancelToken: cancelToken,
      decode: (json) => _unwrapList(json)
          .map(MajorInfo.fromJson)
          .where((item) => item.code.isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<List<SchedulerCourse>> findCourseByMajor({
    required int calendarId,
    required int grade,
    required String code,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findCourseByMajor',
      body: {'calendarId': calendarId, 'grade': grade, 'code': code},
      cancelToken: cancelToken,
      decode: (json) => _unwrapList(json)
          .map(SchedulerCourse.fromJson)
          .where((item) => item.courseCode.isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<List<OptionalCourseType>> findOptionalCourseType(
    int calendarId, {
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findOptionalCourseType',
      body: {'calendarId': calendarId},
      cancelToken: cancelToken,
      decode: (json) => mergeOptionalCourseTypes(
        _unwrapList(json)
            .map(OptionalCourseType.fromJson)
            .where((item) => item.courseLabelId > 0)
            .toList(growable: false),
      ),
    );
  }

  Future<List<SchedulerCourse>> findCourseByNatureId({
    required int calendarId,
    required List<int> ids,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findCourseByNatureId',
      body: {'calendarId': calendarId, 'ids': ids},
      cancelToken: cancelToken,
      decode: (json) {
        final groups = _unwrapList(json);
        return groups
            .expand((group) {
              final map = asJsonMap(group);
              final labelName = readString(map['courseLabelName']) ?? '';
              final courses = map['courses'];
              if (courses is! List) return const <SchedulerCourse>[];
              return courses.map((courseJson) {
                final courseMap = Map<String, Object?>.from(
                  asJsonMap(courseJson),
                );
                courseMap['courseNature'] = [labelName];
                return SchedulerCourse.fromJson(courseMap);
              });
            })
            .where((item) => item.courseCode.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  Future<List<SchedulerCourse>> findCourseBySearch({
    required int calendarId,
    String? courseName,
    String? courseCode,
    String? teacherName,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findCourseBySearch',
      body: {
        'calendarId': calendarId,
        'courseName': courseName ?? '',
        'courseCode': courseCode ?? '',
        'teacherName': teacherName ?? '',
      },
      cancelToken: cancelToken,
      decode: (json) {
        final map = asJsonMap(_unwrapData(json));
        final courses = map['courses'];
        if (courses is! List) return const <SchedulerCourse>[];
        return courses
            .map(SchedulerCourse.fromJson)
            .where((item) => item.courseCode.isNotEmpty)
            .toList(growable: false);
      },
    );
  }

  Future<List<SchedulerClass>> findCourseDetailByCode({
    required int calendarId,
    required String courseCode,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findCourseDetailByCode',
      body: {'calendarId': calendarId, 'courseCode': courseCode},
      cancelToken: cancelToken,
      decode: (json) => _unwrapList(json)
          .map(SchedulerClass.fromJson)
          .where((item) => item.code.isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<List<SchedulerCourse>> hydrateCourseClasses({
    required int calendarId,
    required SchedulerCourse course,
    CancelToken? cancelToken,
  }) async {
    if (course.classes.isNotEmpty) return [course];
    final classes = await findCourseDetailByCode(
      calendarId: calendarId,
      courseCode: course.courseCode,
      cancelToken: cancelToken,
    );
    return [course.copyWith(classes: classes)];
  }

  Future<List<SchedulerCourse>> findCourseByTime({
    required int calendarId,
    required int day,
    required int section,
    CancelToken? cancelToken,
  }) {
    return _client.post(
      '/api/findCourseByTime',
      body: {'calendarId': calendarId, 'day': day, 'section': section},
      cancelToken: cancelToken,
      decode: (json) => _unwrapList(json)
          .map(SchedulerCourse.fromJson)
          .where((item) => item.courseCode.isNotEmpty)
          .toList(growable: false),
    );
  }

  Object? _unwrapData(Object? json) {
    if (json is Map && json.containsKey('data')) return json['data'];
    return json;
  }

  List<Object?> _unwrapList(Object? json) {
    final data = _unwrapData(json);
    if (data is List) return data;
    return const [];
  }
}

List<OptionalCourseType> mergeOptionalCourseTypes(
  List<OptionalCourseType> types,
) {
  final grouped = <String, List<int>>{};
  for (final type in types) {
    final name = type.courseLabelName.trim();
    if (name.isEmpty) continue;
    grouped.putIfAbsent(name, () => []).addAll(type.effectiveCourseLabelIds);
  }
  return grouped.entries
      .map((entry) {
        final ids = entry.value.toSet().toList(growable: false)..sort();
        return OptionalCourseType(
          courseLabelId: ids.first,
          courseLabelName: entry.key,
          courseLabelIds: ids,
        );
      })
      .toList(growable: false);
}
