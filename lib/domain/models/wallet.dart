import 'json_helpers.dart';

/// Wallet credentials generated on first launch.
class WalletCredentials {
  const WalletCredentials({
    required this.mnemonic,
    required this.userHash,
    required this.userSecret,
  });

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

/// Wallet registration returned from the backend.
class WalletRegistration {
  const WalletRegistration({
    required this.userHash,
    required this.userSecret,
    required this.mnemonic,
  });

  factory WalletRegistration.fromJson(Object? json) {
    final map = asJsonMap(json);
    return WalletRegistration(
      userHash: readString(map['user_hash']) ?? '',
      userSecret: readString(map['user_secret']) ?? '',
      mnemonic: readString(map['mnemonic']) ?? '',
    );
  }

  final String userHash;
  final String userSecret;
  final String mnemonic;
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
      userHash: readString(map['user_hash']) ?? '',
      balance: readInt(map['balance']) ?? 0,
      totalEarned: readInt(map['total_earned']),
      totalSpent: readInt(map['total_spent']),
      today: map['today'] != null
          ? WalletTodaySummary.fromJson(map['today'])
          : null,
    );
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
