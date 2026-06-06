import 'json_helpers.dart';

class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.data,
    required this.hasMore,
    this.total,
  });

  factory PaginatedResponse.fromJson(
    Object? json,
    T Function(Object? json) itemFromJson,
  ) {
    final map = asJsonMap(json);
    final data = map['data'];
    return PaginatedResponse<T>(
      data: data is List
          ? data.map(itemFromJson).toList(growable: false)
          : const [],
      hasMore: readBool(map['hasMore']) ?? readBool(map['has_more']) ?? false,
      total: readInt(map['total']),
    );
  }

  final List<T> data;
  final bool hasMore;
  final int? total;
}
