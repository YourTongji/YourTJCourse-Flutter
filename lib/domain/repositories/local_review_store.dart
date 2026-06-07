import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/json_helpers.dart';
import '../models/review.dart';

final localReviewStoreProvider = Provider<LocalReviewStore>((ref) {
  return const LocalReviewStore();
});

class LocalReviewEntry {
  const LocalReviewEntry({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.teacherName,
    required this.courseRating,
    required this.reviewCount,
    required this.review,
    required this.savedAt,
  });

  factory LocalReviewEntry.fromJson(Object? json) {
    final map = asJsonMap(json);
    return LocalReviewEntry(
      courseId: readInt(map['course_id']) ?? 0,
      courseName: readString(map['course_name']) ?? '',
      courseCode: readString(map['course_code']) ?? '',
      teacherName: readString(map['teacher_name']) ?? '',
      courseRating: readDouble(map['course_rating']) ?? 0,
      reviewCount: readInt(map['review_count']) ?? 0,
      review: Review.fromJson(map['review']),
      savedAt: readString(map['saved_at']) ?? '',
    );
  }

  final int courseId;
  final String courseName;
  final String courseCode;
  final String teacherName;
  final double courseRating;
  final int reviewCount;
  final Review review;
  final String savedAt;

  Map<String, Object?> toJson() {
    return {
      'course_id': courseId,
      'course_name': courseName,
      'course_code': courseCode,
      'teacher_name': teacherName,
      'course_rating': courseRating,
      'review_count': reviewCount,
      'review': review.toJson(),
      'saved_at': savedAt,
    };
  }

  LocalReviewEntry copyWith({Review? review, int? reviewCount}) {
    return LocalReviewEntry(
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      teacherName: teacherName,
      courseRating: courseRating,
      reviewCount: reviewCount ?? this.reviewCount,
      review: review ?? this.review,
      savedAt: DateTime.now().toIso8601String(),
    );
  }
}

class LocalReviewStore {
  const LocalReviewStore();

  static const _mineKey = 'de.yourtj.course.localReviews.mine';
  static const _favoriteKey = 'de.yourtj.course.localReviews.favorites';
  static const _hiddenKey = 'de.yourtj.course.localReviews.hidden';

  Future<List<LocalReviewEntry>> loadMine() => _load(_mineKey);

  Future<List<LocalReviewEntry>> loadFavorites() => _load(_favoriteKey);

  Future<List<LocalReviewEntry>> loadHidden() => _load(_hiddenKey);

  Future<Set<int>> loadFavoriteIds() async {
    final entries = await loadFavorites();
    return entries.map((entry) => entry.review.id).toSet();
  }

  Future<void> upsertMine(LocalReviewEntry entry) => _upsert(_mineKey, entry);

  Future<void> upsertFavorite(LocalReviewEntry entry) =>
      _upsert(_favoriteKey, entry);

  Future<void> upsertHidden(LocalReviewEntry entry) =>
      _upsert(_hiddenKey, entry);

  Future<void> removeFavorite(int reviewId) => _remove(_favoriteKey, reviewId);

  Future<void> removeHidden(int reviewId) => _remove(_hiddenKey, reviewId);

  Future<void> updateMineReview(Review review) async {
    final entries = await loadMine();
    final updated = [
      for (final entry in entries)
        if (entry.review.id == review.id)
          entry.copyWith(review: review)
        else
          entry,
    ];
    await _save(_mineKey, updated);
  }

  Future<List<LocalReviewEntry>> _load(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = preferences.getStringList(key) ?? const [];
    return rawItems
        .map((raw) => jsonDecode(raw))
        .map(LocalReviewEntry.fromJson)
        .toList(growable: false);
  }

  Future<void> _upsert(String key, LocalReviewEntry entry) async {
    final entries = await _load(key);
    final next = [
      entry,
      for (final existing in entries)
        if (existing.review.id != entry.review.id) existing,
    ];
    await _save(key, next);
  }

  Future<void> _remove(String key, int reviewId) async {
    final entries = await _load(key);
    await _save(
      key,
      entries
          .where((entry) => entry.review.id != reviewId)
          .toList(growable: false),
    );
  }

  Future<void> _save(String key, List<LocalReviewEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      key,
      entries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList(growable: false),
    );
  }
}
