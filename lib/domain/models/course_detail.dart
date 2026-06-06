import 'course.dart';
import 'json_helpers.dart';
import 'review.dart';

class CourseDetail {
  const CourseDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.teacherName,
    required this.department,
    required this.credit,
    required this.semesters,
    required this.reviews,
    this.description,
    this.isLegacy,
    this.isIcu,
  });

  factory CourseDetail.fromJson(Object? json) {
    final map = asJsonMap(json);
    final reviewsJson = map['reviews'];
    return CourseDetail(
      id: readInt(map['id']) ?? 0,
      code: readString(map['code']) ?? '',
      name: readString(map['name']) ?? '',
      rating: readDouble(map['rating']) ?? readDouble(map['review_avg']) ?? 0,
      reviewCount: readInt(map['review_count']) ?? 0,
      teacherName: readString(map['teacher_name']) ?? '',
      department: readString(map['department']) ?? '',
      credit: readDouble(map['credit']) ?? 0,
      semesters: readStringList(map['semesters']),
      reviews: reviewsJson is List
          ? reviewsJson.map(Review.fromJson).toList(growable: false)
          : const [],
      description: readString(map['description']),
      isLegacy: readBool(map['is_legacy']),
      isIcu: readBool(map['is_icu']),
    );
  }

  final int id;
  final String code;
  final String name;
  final double rating;
  final int reviewCount;
  final String teacherName;
  final String department;
  final double credit;
  final List<String> semesters;
  final List<Review> reviews;
  final String? description;
  final bool? isLegacy;
  final bool? isIcu;

  CourseDetail replacingReview(Review review) {
    return CourseDetail(
      id: id,
      code: code,
      name: name,
      rating: rating,
      reviewCount: reviewCount,
      teacherName: teacherName,
      department: department,
      credit: credit,
      semesters: semesters,
      reviews: [
        for (final existing in reviews)
          if (existing.id == review.id) review else existing,
      ],
      description: description,
      isLegacy: isLegacy,
      isIcu: isIcu,
    );
  }
}

class RelatedCourses {
  const RelatedCourses({
    required this.teacherOtherCourses,
    required this.sameCourseOtherTeachers,
  });

  factory RelatedCourses.fromJson(Object? json) {
    final map = asJsonMap(json);
    final teacher = map['teacher_other_courses'];
    final same = map['same_course_other_teachers'];
    return RelatedCourses(
      teacherOtherCourses: teacher is List
          ? teacher.map(Course.fromJson).toList(growable: false)
          : const [],
      sameCourseOtherTeachers: same is List
          ? same.map(Course.fromJson).toList(growable: false)
          : const [],
    );
  }

  final List<Course> teacherOtherCourses;
  final List<Course> sameCourseOtherTeachers;
}
