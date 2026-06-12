import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_error.dart';
import '../../services/log_writer.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnv());

Dio _createDio(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: const {'Accept': 'application/json'},
    ),
  );
  final startTimes = <int, DateTime>{};
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final id = options.hashCode;
      startTimes[id] = DateTime.now();
      handler.next(options);
    },
    onResponse: (response, handler) {
      final id = response.requestOptions.hashCode;
      final start = startTimes.remove(id);
      final ms = start != null ? DateTime.now().difference(start).inMilliseconds : 0;
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'info',
        'type': 'request',
        'method': response.requestOptions.method,
        'url': response.requestOptions.uri.toString(),
        'statusCode': response.statusCode,
        'duration': ms,
        'message': '${response.requestOptions.method} ${response.statusCode} ${response.requestOptions.path}',
      });
      handler.next(response);
    },
    onError: (error, handler) {
      final id = error.requestOptions.hashCode;
      final start = startTimes.remove(id);
      final ms = start != null ? DateTime.now().difference(start).inMilliseconds : 0;
      LogWriter.instance.write({
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'error',
        'type': 'request',
        'method': error.requestOptions.method,
        'url': error.requestOptions.uri.toString(),
        'statusCode': error.response?.statusCode,
        'duration': ms,
        'message': '${error.requestOptions.method} ${error.response?.statusCode ?? 'ERR'} ${error.requestOptions.path}',
        'error': error.message,
      });
      handler.next(error);
    },
  ));
  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return _createDio(config.apiBaseUrl);
});

final creditDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  return _createDio(config.creditApiBaseUrl);
});

class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
        options: extraHeaders != null ? Options(headers: extraHeaders) : null,
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

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? json) decode,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      () => _dio.patch<Object?>(path, data: body, cancelToken: cancelToken),
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

