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
  });

  factory OptionalCourseType.fromJson(Object? json) {
    final map = asJsonMap(json);
    return OptionalCourseType(
      courseLabelId: readInt(map['courseLabelId']) ?? 0,
      courseLabelName: readString(map['courseLabelName']) ?? '',
    );
  }

  final int courseLabelId;
  final String courseLabelName;
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
    final rawArrangements = map['arrangementInfo'];
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
    return ArrangementInfo(
      arrangementText: readString(map['arrangementText']) ?? '',
      occupyDay: readInt(map['occupyDay']) ?? 0,
      occupyTime: (map['occupyTime'] is List ? map['occupyTime'] as List : [])
          .map(readInt)
          .whereType<int>()
          .where((slot) => slot >= 1 && slot <= 12)
          .toList(growable: false),
      occupyWeek: (map['occupyWeek'] is List ? map['occupyWeek'] as List : [])
          .map(readInt)
          .whereType<int>()
          .toList(growable: false),
      occupyRoom: readString(map['occupyRoom']) ?? '',
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
}
