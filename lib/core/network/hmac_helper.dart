import 'dart:convert';

import 'package:crypto/crypto.dart';

class HmacHelper {
  const HmacHelper._();

  static String editToken({required int reviewId, required String userSecret}) {
    final key = utf8.encode(userSecret);
    final message = utf8.encode('jcourse:edit-review:$reviewId');
    return Hmac(sha256, key).convert(message).toString();
  }
}
