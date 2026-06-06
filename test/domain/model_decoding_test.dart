import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/domain/models/course_detail.dart';

void main() {
  test('decodes backend course detail compatibility fields', () {
    final detail = CourseDetail.fromJson({
      'id': 1,
      'code': '100001',
      'name': '高等数学',
      'review_avg': 4.5,
      'review_count': 32,
      'teacher_name': '张老师',
      'department': '数学科学学院',
      'credit': 5,
      'semesters': ['2025-1'],
      'is_legacy': 0,
      'is_icu': 1,
      'reviews': [
        {
          'id': 9,
          'course_id': 1,
          'semester': '2025-1',
          'rating': 5,
          'comment': '**推荐**',
          'created_at': 1772885683,
          'like_count': 7,
          'liked': true,
          'reviewer_name': '同学',
        },
      ],
    });

    expect(detail.rating, 4.5);
    expect(detail.reviewCount, 32);
    expect(detail.isIcu, isTrue);
    expect(detail.reviews.single.createdAt, '1772885683');
    expect(detail.reviews.single.sqid, '9');
  });
}
