import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

class WalletRepository {
  const WalletRepository(this._client);

  final ApiClient _client;

  /// Register a new wallet (generates mnemonic + keys).
  Future<WalletRegistration> registerWallet({CancelToken? cancelToken}) {
    return _client.post(
      '/api/wallet/register',
      cancelToken: cancelToken,
      decode: WalletRegistration.fromJson,
    );
  }

  /// Get wallet balance and summary for the given user hash.
  Future<CreditWallet> getWallet({
    required String userHash,
    CancelToken? cancelToken,
  }) {
    return _client.get(
      '/api/wallet/$userHash',
      cancelToken: cancelToken,
      decode: CreditWallet.fromJson,
    );
  }

  /// Set edit token for a review (triggers credit reward).
  Future<void> setEditToken({
    required int reviewId,
    required String editToken,
    required String walletUserHash,
    CancelToken? cancelToken,
  }) {
    return _client.patch(
      '/api/review/$reviewId/edit-token',
      body: {
        'edit_token': editToken,
        'walletUserHash': walletUserHash,
      },
      cancelToken: cancelToken,
      decode: (_) {},
    );
  }
}
