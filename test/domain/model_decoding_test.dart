import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/domain/models/ai_summary.dart';
import 'package:yourtjcourse_flutter/domain/models/course_detail.dart';
import 'package:yourtjcourse_flutter/domain/models/runtime_state.dart';
import 'package:yourtjcourse_flutter/features/scheduler/scheduler_models.dart';

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

  test('decodes AI summary response', () {
    final response = AiSummaryResponse.fromJson({
      'data': {
        'rating_consensus': '一致好评',
        'keywords': ['讲课清晰'],
        'pros': ['逻辑清楚'],
        'cons': ['小测偏难'],
        'representative': [
          {'text': '老师讲得很好', 'sentiment': 'positive'},
        ],
      },
      'generatedAt': 1780000000000,
      'cache': 'db',
    });

    expect(response.data.hasContent, isTrue);
    expect(response.data.keywords.single, '讲课清晰');
    expect(response.data.representative.single.sentiment, 'positive');
  });

  test('decodes runtime announcements', () {
    final state = RuntimeState.fromJson({
      'maintenance': {'enabled': false},
      'announcements': [
        {'id': 'a1', 'type': 'success', 'content': '已更新'},
        {'id': 'a2', 'content': '隐藏', 'enabled': false},
      ],
      'updatedAt': 1780000000000,
    });

    expect(state.maintenance.enabled, isFalse);
    expect(state.announcements.single.title, '更新');
    expect(state.announcements.single.content, '已更新');
  });

  test('decodes scheduler major courses and teaching classes', () {
    final course = SchedulerCourse.fromJson({
      'courseCode': '003030',
      'courseName': '代数前沿选讲1',
      'faculty': '数学科学学院',
      'credit': 0.5,
      'grade': 2023,
      'courseNature': ['专业选修课'],
      'courses': [
        {
          'code': '00303001',
          'campus': '四平路校区',
          'teachers': [
            {'teacherCode': '25171', 'teacherName': '林老师'},
          ],
          'teachingLanguage': '中文',
          'arrangementInfo': [
            {
              'arrangementText': '星期二3-4节 [1-16] 北118',
              'occupyDay': 2,
              'occupyTime': [3, 4],
              'occupyWeek': [1, 2],
              'occupyRoom': '北118',
              'teacherAndCode': '林老师(25171)',
            },
          ],
          'isExclusive': false,
        },
      ],
    });

    expect(course.courseCode, '003030');
    expect(course.classes, hasLength(1));
    expect(course.classes.single.code, '00303001');
    expect(course.classes.single.arrangements.single.occupyTime, [3, 4]);
  });
}
