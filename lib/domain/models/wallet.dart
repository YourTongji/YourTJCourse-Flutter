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

/// Unwraps the credit API envelope: { success: bool, data: T, error: string }.
/// Throws [CreditApiException] when the API returns an error.
T _unwrapCreditResponse<T>(Object? json, T Function(Object?) fromJson) {
  if (json is! Map) throw const CreditApiException('响应格式错误');
  final success = json['success'] == true;
  if (!success) {
    final error = json['error'] is String
        ? json['error'] as String
        : json['message'] is String
            ? json['message'] as String
            : '未知错误';
    throw CreditApiException(error);
  }
  final data = json['data'];
  if (data == null) throw const CreditApiException('响应数据为空');
  return fromJson(data);
}

/// Wallet credentials — generated client-side from a random seed.
/// Keys are deterministic from the mnemonic.
class WalletCredentials {
  const WalletCredentials({
    required this.mnemonic,
    required this.userHash,
    required this.userSecret,
  });

  /// Generate fresh credentials from a random seed.
  factory WalletCredentials.generate() {
    final seed = List<int>.generate(16, (_) => math.Random().nextInt(256));
    final sha = sha256.convert(seed).bytes;
    final userHash = sha.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final userSecret = base64Encode(sha);
    // Simple mnemonic from hex encoding of the seed.
    final mnemonic = seed.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return WalletCredentials(mnemonic: mnemonic, userHash: userHash, userSecret: userSecret);
  }

  factory WalletCredentials.fromJson(Object? json) {
    final map = asJsonMap(json);
    return WalletCredentials(
      mnemonic: readString(map['mnemonic']) ?? '',
      userHash: readString(map['user_hash']) ?? '',
      userSecret: readString(map['user_secret']) ?? '',
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

/// Credit wallet snapshot from the backend.
class CreditWallet {
  const CreditWallet({
    required this.userHash,
    this.balance = 0,
    this.totalEarned,
    this.totalSpent,
    this.today,
  });

  factory CreditWallet.fromJson(Object? json) {
    final map = asJsonMap(json);
    return CreditWallet(
      userHash: readString(map['userHash']) ?? readString(map['user_hash']) ?? '',
      balance: readInt(map['balance']) ?? 0,
      totalEarned: readInt(map['totalEarned']) ?? readInt(map['total_earned']),
      totalSpent: readInt(map['totalSpent']) ?? readInt(map['total_spent']),
      today: map['today'] != null
          ? WalletTodaySummary.fromJson(map['today'])
          : null,
    );
  }

  /// Parse from the credit API response envelope.
  /// Throws [CreditApiException] on error.
  static CreditWallet fromApiResponse(Object? json) {
    return _unwrapCreditResponse(json, CreditWallet.fromJson);
  }

  final String userHash;
  final int balance;
  final int? totalEarned;
  final int? totalSpent;
  final WalletTodaySummary? today;
}

/// Today's wallet activity summary.
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
