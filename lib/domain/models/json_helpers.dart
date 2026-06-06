int? readInt(Object? value) {
  if (value is int) return value;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? readDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? readBool(Object? value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return null;
}

String? readString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

List<String> readStringList(Object? value) {
  if (value is! List) return const [];
  return value.map(readString).whereType<String>().toList(growable: false);
}

Map<String, dynamic> asJsonMap(Object? json) {
  if (json is Map<String, dynamic>) return json;
  if (json is Map) return Map<String, dynamic>.from(json);
  throw const FormatException('响应格式错误');
}
