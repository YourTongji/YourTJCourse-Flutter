import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_error.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnv());

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: const {'Accept': 'application/json'},
    ),
  );
});

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );
    return decode(response.data);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.post<Object?>(path, data: body, cancelToken: cancelToken),
    );
    return decode(response.data);
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.put<Object?>(path, data: body, cancelToken: cancelToken),
    );
    return decode(response.data);
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.delete<Object?>(path, data: body, cancelToken: cancelToken),
    );
    return decode(response.data);
  }

  Future<Response<Object?>> _request(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      final status = error.response?.statusCode;
      throw ApiException(
        _messageForStatus(status) ?? error.message ?? '网络请求失败',
        statusCode: status,
      );
    }
  }

  String? _messageForStatus(int? statusCode) {
    return switch (statusCode) {
      400 => '请求参数错误',
      401 => '认证已失效',
      403 => '验证失败',
      404 => '内容不存在',
      429 => '请求太频繁',
      _ when statusCode != null && statusCode >= 500 => '服务暂时不可用',
      _ => null,
    };
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});
