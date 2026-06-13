import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'json_helpers.dart';

/// Error thrown when the credit API returns a non-success response.
class CreditApiException implements Exception {
  const CreditApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Unwraps the credit API envelope: { success, data?, error? }.
T _unwrapCreditResponse<T>(Object? json, T Function(Object?) fromJson) {
  if (json is! Map) throw const CreditApiException('响应格式错误');
  if (json['success'] != true) {
    final msg = json['error'] ?? json['message'] ?? '未知错误';
    throw CreditApiException('$msg');
  }
  final data = json['data'];
  if (data == null) throw const CreditApiException('响应数据为空');
  return fromJson(data);
}

/// Wallet credentials — generated client-side from a random seed.
class WalletCredentials {
  const WalletCredentials({
    required this.mnemonic,
    required this.userHash,
    required this.userSecret,
  });

  /// Generate fresh credentials.
  factory WalletCredentials.generate() {
    final seed = List<int>.generate(16, (_) => math.Random().nextInt(256));
    final sha = sha256.convert(seed).bytes;
    final userHash = sha.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final userSecret = base64Encode(sha);
    final mnemonic = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return WalletCredentials(mnemonic: mnemonic, userHash: userHash, userSecret: userSecret);
  }

  factory WalletCredentials.fromJson(Object? json) {
    final map = asJsonMap(json);
    return WalletCredentials(
      mnemonic: readString(map['mnemonic']) ?? '',
      userHash: readString(map['user_hash']) ?? readString(map['userHash']) ?? '',
      userSecret: readString(map['user_secret']) ?? readString(map['userSecret']) ?? '',
    );
  }

  Map<String, String> toJson() => {
    'mnemonic': mnemonic,
    'user_hash': userHash,
    'user_secret': userSecret,
  };

  final String mnemonic;
  final String userHash;
  final String userSecret;
}

/// Wallet snapshot returned by the credit server's wallet endpoints.
/// Fields returned by the server are in camelCase.
class CreditWallet {
  const CreditWallet({
    required this.userHash,
    this.balance = 0,
    this.createdAt,
    this.lastActiveAt,
  });

  factory CreditWallet.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CreditWallet(
      userHash: readString(map['userHash']) ?? readString(map['user_hash']) ?? '',
      balance: readInt(map['balance']) ?? 0,
      createdAt: readInt(map['createdAt']),
      lastActiveAt: readInt(map['lastActiveAt']),
    );
  }

  static CreditWallet fromApiResponse(Object? json) =>
      _unwrapCreditResponse(json, CreditWallet.fromJson);

  final String userHash;
  final int balance;
  final int? createdAt;
  final int? lastActiveAt;
}

/// Extended summary from GET /api/integration/jcourse?action=summary
class WalletSummary {
  const WalletSummary({
    required this.userHash,
    this.balance = 0,
    this.date,
    this.today,
  });

  factory WalletSummary.fromJson(Object? json) {
    final map = asJsonMap(json);
    return WalletSummary(
      userHash: readString(map['userHash']) ?? readString(map['user_hash']) ?? '',
      balance: readInt(map['balance']) ?? 0,
      date: readString(map['date']),
      today: map['today'] != null
          ? WalletTodaySummary.fromJson(map['today'])
          : null,
    );
  }

  static WalletSummary? fromApiResponse(Object? json) {
    try {
      return _unwrapCreditResponse(json, WalletSummary.fromJson);
    } catch (_) {
      return null;
    }
  }

  final String userHash;
  final int balance;
  final String? date;
  final WalletTodaySummary? today;
}

class WalletTodaySummary {
  const WalletTodaySummary({
    this.reviewReward = 0,
    this.likePendingDelta = 0,
    this.likePendingPoints = 0,
  });

  factory WalletTodaySummary.fromJson(Object? json) {
    final map = asJsonMap(json);
    return WalletTodaySummary(
      reviewReward: readInt(map['reviewReward']) ?? readInt(map['review_reward']) ?? 0,
      likePendingDelta: readInt(map['likePendingDelta']) ?? readInt(map['like_pending_delta']) ?? 0,
      likePendingPoints: readInt(map['likePendingPoints']) ?? readInt(map['like_pending_points']) ?? 0,
    );
  }

  final int reviewReward;
  final int likePendingDelta;
  final int likePendingPoints;
}
