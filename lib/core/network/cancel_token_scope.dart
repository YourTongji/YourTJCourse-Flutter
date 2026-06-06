import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

CancelToken scopedCancelToken(Ref ref) {
  final token = CancelToken();
  ref.onDispose(() {
    if (!token.isCancelled) {
      token.cancel('provider disposed');
    }
  });
  return token;
}
