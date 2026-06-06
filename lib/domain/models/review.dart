import 'json_helpers.dart';

class Review {
  const Review({
    required this.id,
    required this.sqid,
    required this.courseId,
    required this.semester,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.likeCount,
    required this.liked,
    this.reviewerName,
    this.reviewerAvatar,
  });

  factory Review.fromJson(Object? json) {
    final map = asJsonMap(json);
    final id = readInt(map['id']) ?? 0;
    return Review(
      id: id,
      sqid: readString(map['sqid']) ?? id.toString(),
      courseId: readInt(map['course_id']) ?? 0,
      semester: readString(map['semester']) ?? '',
      rating: readInt(map['rating']) ?? 0,
      comment: readString(map['comment']) ?? '',
      createdAt: readString(map['created_at']) ?? '',
      likeCount: readInt(map['like_count']) ?? 0,
      liked: readBool(map['liked']) ?? false,
      reviewerName: readString(map['reviewer_name']),
      reviewerAvatar: readString(map['reviewer_avatar']),
    );
  }

  final int id;
  final String sqid;
  final int courseId;
  final String semester;
  final int rating;
  final String comment;
  final String createdAt;
  final int likeCount;
  final bool liked;
  final String? reviewerName;
  final String? reviewerAvatar;

  Review copyWith({bool? liked, int? likeCount}) {
    return Review(
      id: id,
      sqid: sqid,
      courseId: courseId,
      semester: semester,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      liked: liked ?? this.liked,
      reviewerName: reviewerName,
      reviewerAvatar: reviewerAvatar,
    );
  }
}
