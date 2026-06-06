import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ClientIdStore {
  static const _key = 'de.yourtj.course.clientId';
  static const _uuid = Uuid();

  Future<String> loadOrCreate() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await preferences.setString(_key, created);
    return created;
  }
}
