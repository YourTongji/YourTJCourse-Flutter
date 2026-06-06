import 'package:flutter_test/flutter_test.dart';
import 'package:yourtjcourse_flutter/core/network/hmac_helper.dart';

void main() {
  test('computes edit token using backend-compatible message', () {
    final token = HmacHelper.editToken(reviewId: 42, userSecret: 'secret');

    expect(
      token,
      'bf95e6253a46e29b4d6f7bb05151a541e5a6772625bea71cd974e797540c34c6',
    );
  });
}
