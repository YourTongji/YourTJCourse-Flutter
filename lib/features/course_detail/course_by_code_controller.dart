import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../domain/models/course_detail.dart';
import '../../domain/repositories/course_repository.dart';

typedef CourseByCodeQuery = ({
  String code,
  String? teacherCode,
  String? teacherName,
});

final courseByCodeControllerProvider = AsyncNotifierProvider.autoDispose
    .family<CourseByCodeController, CourseDetail, CourseByCodeQuery>(
      CourseByCodeController.new,
    );

class CourseByCodeController extends AsyncNotifier<CourseDetail> {
  CourseByCodeController(this._query);

  final CourseByCodeQuery _query;

  @override
  Future<CourseDetail> build() {
    final token = scopedCancelToken(ref);
    return ref
        .watch(courseRepositoryProvider)
        .getCourseByCode(
          code: _query.code,
          teacherCode: _query.teacherCode,
          teacherName: _query.teacherName,
          cancelToken: token,
        );
  }
}
