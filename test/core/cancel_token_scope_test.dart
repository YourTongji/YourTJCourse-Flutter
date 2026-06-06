import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/core/network/cancel_token_scope.dart';

final _tokenProvider = Provider.autoDispose<CancelToken>(scopedCancelToken);

void main() {
  test('cancels Dio token when provider is disposed', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final subscription = container.listen(_tokenProvider, (_, _) {});
    final token = container.read(_tokenProvider);

    expect(token.isCancelled, isFalse);
    subscription.close();
    await container.pump();

    expect(token.isCancelled, isTrue);
  });
}
