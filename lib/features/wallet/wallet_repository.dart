import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/models/wallet.dart';

/// Provider for the wallet/credit API client (points to core.credit.yourtj.de).
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    ref.watch(creditDioProvider),
    ref.watch(apiClientProvider),
  );
});

class WalletRepository {
  const WalletRepository(this._creditDio, this._mainClient);

  final Dio _creditDio;
  final ApiClient _mainClient;

  /// Register a new wallet with the given credentials.
  Future<CreditWallet> registerWallet(WalletCredentials creds, {CancelToken? cancelToken}) async {
    final response = await _creditDio.post<Object?>(
      '/api/wallet/register',
      data: {
        'user_hash': creds.userHash,
        'user_secret': creds.userSecret,
      },
      cancelToken: cancelToken,
    );
    return CreditWallet.fromApiResponse(response.data) ??
        CreditWallet(userHash: creds.userHash, balance: 0);
  }

  /// Get wallet balance and summary for the given user hash.
  Future<CreditWallet> getWallet({
    required String userHash,
    CancelToken? cancelToken,
  }) async {
    final response = await _creditDio.get<Object?>(
      '/api/wallet/$userHash',
      cancelToken: cancelToken,
    );
    return CreditWallet.fromApiResponse(response.data) ??
        CreditWallet(userHash: userHash, balance: 0);
  }

  /// Set edit token for a review (triggers credit reward).
  /// This endpoint is on the main API server, not the credit server.
  Future<void> setEditToken({
    required int reviewId,
    required String editToken,
    required String walletUserHash,
    CancelToken? cancelToken,
  }) {
    return _mainClient.patch(
      '/api/review/$reviewId/edit-token',
      body: {
        'edit_token': editToken,
        'wallet_user_hash': walletUserHash,
      },
      cancelToken: cancelToken,
      decode: (_) {},
    );
  }
}
