// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/models/review.dart';

/// Pending edit review: set by the profile page "再次编辑" action.
/// The course detail page reads this on load and auto-opens the edit sheet.
///
/// Must use StateNotifier to avoid Provider.family caching stale values.
class PendingEditNotifier extends StateNotifier<Map<int, Review?>> {
  PendingEditNotifier() : super({});

  void set(int courseId, Review review) {
    state = {...state, courseId: review};
  }

  void clear(int courseId) {
    state = {...state, courseId: null};
  }
}

final pendingEditProvider =
    StateNotifierProvider<PendingEditNotifier, Map<int, Review?>>((ref) {
  return PendingEditNotifier();
});
