import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/runtime_state.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(apiClientProvider));
});

class SettingsRepository {
  const SettingsRepository(this._client);

  final ApiClient _client;

  Future<List<String>> getDepartments({CancelToken? cancelToken}) {
    return _client.get(
      '/api/departments',
      cancelToken: cancelToken,
      decode: (json) {
        final map = json as Map;
        final departments = map['departments'];
        if (departments is! List) return const <String>[];
        return departments.whereType<String>().toList(growable: false);
      },
    );
  }

  Future<RuntimeState> getRuntimeState({
    Map<String, String>? extraHeaders,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/settings/runtime-state',
      queryParameters: {'_t': '${DateTime.now().millisecondsSinceEpoch}'},
      extraHeaders: {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        ...?extraHeaders,
      },
      cancelToken: cancelToken,
      decode: RuntimeState.fromJson,
    );
  }
}
