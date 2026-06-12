import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/review.dart';

/// Pending edit review: set by the profile page "再次编辑" action.
/// The course detail page reads this on load and auto-opens the edit sheet.
class PendingEditNotifier extends Notifier<Map<int, Review?>> {
  @override
  Map<int, Review?> build() => {};

  void set(int courseId, Review review) {
    state = {...state, courseId: review};
  }

  void clear(int courseId) {
    state = Map.of(state)..remove(courseId);
  }
}

final pendingEditProvider =
    NotifierProvider<PendingEditNotifier, Map<int, Review?>>(
      PendingEditNotifier.new,
    );
