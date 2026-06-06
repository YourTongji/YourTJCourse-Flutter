import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_states.dart';
import 'course_by_code_controller.dart';
import 'course_detail_view.dart';

class CourseByCodeView extends ConsumerWidget {
  const CourseByCodeView({
    super.key,
    required this.courseCode,
    this.teacherCode,
    this.teacherName,
  });

  final String courseCode;
  final String? teacherCode;
  final String? teacherName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      courseByCodeControllerProvider((
        code: courseCode,
        teacherCode: teacherCode,
        teacherName: teacherName,
      )),
    );
    return detail.when(
      loading: () => const Scaffold(body: LoadingState(message: '正在查找课程评价')),
      error: (error, _) =>
          Scaffold(body: ErrorState(message: error.toString())),
      data: (course) => CourseDetailView(courseId: course.id),
    );
  }
}
