import 'json_helpers.dart';

class Course {
  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.isLegacy,
    required this.teacherName,
    required this.department,
    required this.credit,
    required this.semesters,
  });

  factory Course.fromJson(Object? json) {
    final map = asJsonMap(json);
    return Course(
      id: readInt(map['id']) ?? 0,
      code: readString(map['code']) ?? '',
      name: readString(map['name']) ?? '',
      rating: readDouble(map['rating']) ?? readDouble(map['review_avg']) ?? 0,
      reviewCount: readInt(map['review_count']) ?? 0,
      isLegacy: readInt(map['is_legacy']) ?? 0,
      teacherName: readString(map['teacher_name']) ?? '',
      department: readString(map['department']) ?? '',
      credit: readDouble(map['credit']) ?? 0,
      semesters: readStringList(map['semesters']),
    );
  }

  final int id;
  final String code;
  final String name;
  final double rating;
  final int reviewCount;
  final int isLegacy;
  final String teacherName;
  final String department;
  final double credit;
  final List<String> semesters;

  Course copyWith({
    int? id,
    String? code,
    String? name,
    double? rating,
    int? reviewCount,
    int? isLegacy,
    String? teacherName,
    String? department,
    double? credit,
    List<String>? semesters,
  }) {
    return Course(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isLegacy: isLegacy ?? this.isLegacy,
      teacherName: teacherName ?? this.teacherName,
      department: department ?? this.department,
      credit: credit ?? this.credit,
      semesters: semesters ?? this.semesters,
    );
  }
}
