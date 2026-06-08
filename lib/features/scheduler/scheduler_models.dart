import '../../domain/models/json_helpers.dart';

class CalendarTerm {
  const CalendarTerm({required this.calendarId, required this.calendarName});

  factory CalendarTerm.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CalendarTerm(
      calendarId: readInt(map['calendarId']) ?? 0,
      calendarName: readString(map['calendarName']) ?? '',
    );
  }

  final int calendarId;
  final String calendarName;
}

class MajorInfo {
  const MajorInfo({required this.code, required this.name});

  factory MajorInfo.fromJson(Object? json) {
    final map = asJsonMap(json);
    return MajorInfo(
      code: readString(map['code']) ?? '',
      name: readString(map['name']) ?? '',
    );
  }

  final String code;
  final String name;
}

class CampusInfo {
  const CampusInfo({required this.campusId, required this.campusName});

  factory CampusInfo.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CampusInfo(
      campusId: readString(map['campusId']) ?? '',
      campusName: readString(map['campusName']) ?? '',
    );
  }

  final String campusId;
  final String campusName;
}

class FacultyInfo {
  const FacultyInfo({required this.facultyId, required this.facultyName});

  factory FacultyInfo.fromJson(Object? json) {
    final map = asJsonMap(json);
    return FacultyInfo(
      facultyId: readString(map['facultyId']) ?? '',
      facultyName: readString(map['facultyName']) ?? '',
    );
  }

  final String facultyId;
  final String facultyName;
}

class OptionalCourseType {
  const OptionalCourseType({
    required this.courseLabelId,
    required this.courseLabelName,
    this.courseLabelIds = const [],
  });

  factory OptionalCourseType.fromJson(Object? json) {
    final map = asJsonMap(json);
    final id = readInt(map['courseLabelId']) ?? 0;
    return OptionalCourseType(
      courseLabelId: id,
      courseLabelName: readString(map['courseLabelName']) ?? '',
      courseLabelIds: [id],
    );
  }

  final int courseLabelId;
  final String courseLabelName;
  final List<int> courseLabelIds;

  List<int> get effectiveCourseLabelIds {
    if (courseLabelIds.isEmpty) return [courseLabelId];
    return courseLabelIds;
  }
}

class SchedulerCourse {
  const SchedulerCourse({
    required this.courseCode,
    required this.courseName,
    required this.credit,
    required this.faculty,
    required this.courseNature,
    required this.campus,
    required this.classes,
    this.grade,
  });

  factory SchedulerCourse.fromJson(Object? json) {
    final map = asJsonMap(json);
    final rawClasses = map['courses'];
    return SchedulerCourse(
      courseCode: readString(map['courseCode']) ?? '',
      courseName: readString(map['courseName']) ?? '',
      credit: readDouble(map['credit']) ?? 0,
      faculty:
          readString(map['faculty']) ?? readString(map['facultyI18n']) ?? '',
      courseNature: readStringList(map['courseNature']),
      campus: readStringList(map['campus'] ?? map['campus_list']),
      grade: readInt(map['grade']),
      classes: rawClasses is List
          ? rawClasses.map(SchedulerClass.fromJson).toList(growable: false)
          : const [],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credit': credit,
      'faculty': faculty,
      'courseNature': courseNature,
      'campus': campus,
      'grade': grade,
      'courses': classes.map((item) => item.toJson()).toList(growable: false),
    };
  }

  SchedulerCourse copyWith({List<SchedulerClass>? classes}) {
    return SchedulerCourse(
      courseCode: courseCode,
      courseName: courseName,
      credit: credit,
      faculty: faculty,
      courseNature: courseNature,
      campus: campus,
      classes: classes ?? this.classes,
      grade: grade,
    );
  }

  final String courseCode;
  final String courseName;
  final double credit;
  final String faculty;
  final List<String> courseNature;
  final List<String> campus;
  final int? grade;
  final List<SchedulerClass> classes;
}

class SchedulerClass {
  const SchedulerClass({
    required this.code,
    required this.campus,
    required this.teachers,
    required this.teachingLanguage,
    required this.arrangements,
    this.isExclusive = false,
    this.status,
  });

  factory SchedulerClass.fromJson(Object? json) {
    final map = asJsonMap(json);
    final rawTeachers = map['teachers'];
    final rawArrangements =
        map['arrangementInfo'] ?? map['arrangements'] ?? map['arrangeInfo'];
    return SchedulerClass(
      code: readString(map['code']) ?? '',
      campus: readString(map['campus']) ?? '',
      teachingLanguage: readString(map['teachingLanguage']) ?? '',
      isExclusive: readBool(map['isExclusive']) ?? false,
      status: readInt(map['status']),
      teachers: rawTeachers is List
          ? rawTeachers.map(TeacherInfo.fromJson).toList(growable: false)
          : const [],
      arrangements: rawArrangements is List
          ? rawArrangements
                .map(ArrangementInfo.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'campus': campus,
      'teachers': teachers.map((item) => item.toJson()).toList(growable: false),
      'teachingLanguage': teachingLanguage,
      'arrangementInfo': arrangements
          .map((item) => item.toJson())
          .toList(growable: false),
      'isExclusive': isExclusive,
      'status': status,
    };
  }

  final String code;
  final String campus;
  final List<TeacherInfo> teachers;
  final String teachingLanguage;
  final List<ArrangementInfo> arrangements;
  final bool isExclusive;
  final int? status;
}

class SchedulerClassReviewInfo {
  const SchedulerClassReviewInfo({
    required this.rating,
    required this.reviewCount,
  });

  final double rating;
  final int reviewCount;

  String get ratingGrade {
    if (reviewCount <= 0) return '暂无';
    if (rating >= 4.5) return '优秀';
    if (rating >= 4.0) return '推荐';
    if (rating >= 3.0) return '中等';
    return '谨慎';
  }

  String get ratingText {
    if (reviewCount <= 0) return '暂无评课';
    return '$ratingGrade ${rating.toStringAsFixed(1)} · $reviewCount 评';
  }
}

class TeacherInfo {
  const TeacherInfo({required this.teacherName, required this.teacherCode});

  factory TeacherInfo.fromJson(Object? json) {
    final map = asJsonMap(json);
    return TeacherInfo(
      teacherName: readString(map['teacherName']) ?? '',
      teacherCode: readString(map['teacherCode']) ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {'teacherName': teacherName, 'teacherCode': teacherCode};
  }

  final String teacherName;
  final String teacherCode;
}

class ArrangementInfo {
  const ArrangementInfo({
    required this.arrangementText,
    required this.occupyDay,
    required this.occupyTime,
    required this.occupyWeek,
    required this.occupyRoom,
    required this.teacherAndCode,
  });

  factory ArrangementInfo.fromJson(Object? json) {
    final map = asJsonMap(json);
    final arrangementText = readString(map['arrangementText']) ?? '';
    final parsed = _ParsedArrangement.fromText(arrangementText);
    return ArrangementInfo(
      arrangementText: arrangementText,
      occupyDay: readInt(map['occupyDay']) ?? parsed.occupyDay,
      occupyTime: _readIntList(map['occupyTime'])
          .map(readInt)
          .whereType<int>()
          .where((slot) => slot >= 1 && slot <= 12)
          .toList(growable: false)
          .ifEmpty(parsed.occupyTime),
      occupyWeek: _readIntList(map['occupyWeek'])
          .map(readInt)
          .whereType<int>()
          .toList(growable: false)
          .ifEmpty(parsed.occupyWeek),
      occupyRoom: readString(map['occupyRoom']) ?? parsed.occupyRoom,
      teacherAndCode: readString(map['teacherAndCode']) ?? '',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'arrangementText': arrangementText,
      'occupyDay': occupyDay,
      'occupyTime': occupyTime,
      'occupyWeek': occupyWeek,
      'occupyRoom': occupyRoom,
      'teacherAndCode': teacherAndCode,
    };
  }

  final String arrangementText;
  final int occupyDay;
  final List<int> occupyTime;
  final List<int> occupyWeek;
  final String occupyRoom;
  final String teacherAndCode;

  bool occupies(int day, int slot) {
    return occupyDay == day && occupyTime.contains(slot);
  }
}

class ScheduledClass {
  const ScheduledClass({required this.course, required this.classInfo});

  factory ScheduledClass.fromJson(Object? json) {
    final map = asJsonMap(json);
    return ScheduledClass(
      course: SchedulerCourse.fromJson(map['course']),
      classInfo: SchedulerClass.fromJson(map['classInfo']),
    );
  }

  final SchedulerCourse course;
  final SchedulerClass classInfo;

  Map<String, Object?> toJson() {
    return {'course': course.toJson(), 'classInfo': classInfo.toJson()};
  }

  bool occupies(int day, int slot) {
    return classInfo.arrangements.any(
      (arrangement) => arrangement.occupies(day, slot),
    );
  }
}

List<Object?> _readIntList(Object? value) {
  if (value is List) return value;
  if (value is String) {
    return value
        .split(RegExp(r'[,，\s]+'))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

class _ParsedArrangement {
  const _ParsedArrangement({
    required this.occupyDay,
    required this.occupyTime,
    required this.occupyWeek,
    required this.occupyRoom,
  });

  factory _ParsedArrangement.fromText(String text) {
    final day = _parseDay(text);
    final time = _parseTime(text);
    final week = _parseWeek(text);
    return _ParsedArrangement(
      occupyDay: day,
      occupyTime: time,
      occupyWeek: week,
      occupyRoom: _parseRoom(text),
    );
  }

  final int occupyDay;
  final List<int> occupyTime;
  final List<int> occupyWeek;
  final String occupyRoom;
}

int _parseDay(String text) {
  const days = {
    '星期一': 1,
    '周一': 1,
    '星期二': 2,
    '周二': 2,
    '星期三': 3,
    '周三': 3,
    '星期四': 4,
    '周四': 4,
    '星期五': 5,
    '周五': 5,
    '星期六': 6,
    '周六': 6,
    '星期日': 7,
    '星期天': 7,
    '周日': 7,
    '周天': 7,
  };
  for (final entry in days.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return 0;
}

List<int> _parseTime(String text) {
  final match = RegExp(
    r'(?:星期[一二三四五六日天]|周[一二三四五六日天])\s*(\d{1,2})(?:\s*[-~－]\s*(\d{1,2}))?\s*节',
  ).firstMatch(text);
  if (match == null) return const [];
  final start = int.tryParse(match.group(1) ?? '');
  final end = int.tryParse(match.group(2) ?? '') ?? start;
  if (start == null || end == null || start < 1 || end < start) {
    return const [];
  }
  return [for (var slot = start; slot <= end && slot <= 12; slot++) slot];
}

List<int> _parseWeek(String text) {
  final match = RegExp(r'\[([^\]]+)\]').firstMatch(text);
  if (match == null) return const [];
  final raw = (match.group(1) ?? '').replaceAll('周', '').trim();
  final weeks = <int>{};
  for (final part in raw.split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    final isOdd = part.contains('单');
    final isEven = part.contains('双');
    final cleaned = part.replaceAll(RegExp(r'[单双()（）]'), '');
    final range = cleaned.split('-');
    if (range.length == 1) {
      final week = int.tryParse(range.single);
      if (week != null) weeks.add(week);
      continue;
    }
    final start = int.tryParse(range.first);
    final end = int.tryParse(range.last);
    if (start == null || end == null || end < start) continue;
    for (var week = start; week <= end; week++) {
      if (isOdd && week.isEven) continue;
      if (isEven && week.isOdd) continue;
      weeks.add(week);
    }
  }
  return weeks.toList(growable: false)..sort();
}

String _parseRoom(String text) {
  final end = text.indexOf(']');
  if (end < 0 || end + 1 >= text.length) return '';
  return text.substring(end + 1).trim();
}

extension _ListFallback<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) {
    return isEmpty ? fallback : this;
  }
}

// ─── Course change detection models ──────────────────────────────────

/// What kind of change was detected for a course.
enum CourseChangeType { closed, infoChanged, conflictAfterUpdate }

/// Details of a single course change.
class CourseChange {
  const CourseChange({
    required this.type,
    required this.courseCode,
    required this.courseName,
    this.detail,
    this.affectedCodes = const [],
  });

  factory CourseChange.fromJson(Object? json) {
    final map = asJsonMap(json);
    final raw = readString(map['type']) ?? '';
    return CourseChange(
      type: CourseChangeType.values.firstWhere(
        (t) => t.name == raw,
        orElse: () => CourseChangeType.infoChanged,
      ),
      courseCode: readString(map['courseCode']) ?? '',
      courseName: readString(map['courseName']) ?? '',
      detail: readString(map['detail']),
      affectedCodes: readStringList(map['affectedCodes']),
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'courseCode': courseCode,
    'courseName': courseName,
    'detail': detail,
    'affectedCodes': affectedCodes,
  };

  final CourseChangeType type;
  final String courseCode;
  final String courseName;
  final String? detail;
  final List<String> affectedCodes;
}

/// Snapshot of a scheduled class used for change detection.
class ScheduledClassSnapshot {
  const ScheduledClassSnapshot({
    required this.classCode,
    required this.courseCode,
    required this.courseName,
    required this.teacherNames,
    required this.arrangementTexts,
  });

  factory ScheduledClassSnapshot.fromScheduledClass(ScheduledClass sc) {
    return ScheduledClassSnapshot(
      classCode: sc.classInfo.code,
      courseCode: sc.course.courseCode,
      courseName: sc.course.courseName,
      teacherNames: sc.classInfo.teachers
          .map((t) => t.teacherName)
          .where((n) => n.isNotEmpty)
          .toList(growable: false),
      arrangementTexts: sc.classInfo.arrangements
          .map((a) => a.arrangementText)
          .where((t) => t.isNotEmpty)
          .toList(growable: false),
    );
  }

  factory ScheduledClassSnapshot.fromJson(Object? json) {
    final map = asJsonMap(json);
    return ScheduledClassSnapshot(
      classCode: readString(map['classCode']) ?? '',
      courseCode: readString(map['courseCode']) ?? '',
      courseName: readString(map['courseName']) ?? '',
      teacherNames: readStringList(map['teacherNames']),
      arrangementTexts: readStringList(map['arrangementTexts']),
    );
  }

  Map<String, Object?> toJson() => {
    'classCode': classCode,
    'courseCode': courseCode,
    'courseName': courseName,
    'teacherNames': teacherNames,
    'arrangementTexts': arrangementTexts,
  };

  final String classCode;
  final String courseCode;
  final String courseName;
  final List<String> teacherNames;
  final List<String> arrangementTexts;
}
