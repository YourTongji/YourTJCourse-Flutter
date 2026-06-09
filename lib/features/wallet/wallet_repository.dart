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

  /// Register wallet with the credit server.
  Future<CreditWallet> registerWallet(WalletCredentials creds, {CancelToken? cancelToken}) async {
    final r = await _creditDio.post<Object?>(
      '/api/wallet/register',
      data: {'userHash': creds.userHash, 'userSecret': creds.userSecret},
      cancelToken: cancelToken,
    );
    return CreditWallet.fromApiResponse(r.data);
  }

  /// Fetch basic wallet info from the credit server.
  Future<CreditWallet> fetchWallet(String userHash, {CancelToken? cancelToken}) async {
    final r = await _creditDio.get<Object?>(
      '/api/wallet/$userHash',
      cancelToken: cancelToken,
    );
    return CreditWallet.fromApiResponse(r.data);
  }

  /// Fetch extended summary (balance + today's activity) from jcourse integration.
  Future<WalletSummary?> fetchSummary(String userHash, {CancelToken? cancelToken}) async {
    try {
      final r = await _creditDio.get<Object?>(
        '/api/integration/jcourse/summary',
        queryParameters: {'userHash': userHash},
        cancelToken: cancelToken,
      );
      return WalletSummary.fromApiResponse(r.data);
    } catch (_) {
      return null; // summary is optional — wallet works without it
    }
  }

  /// Set edit token on the main API server.
  Future<void> setEditToken({
    required int reviewId,
    required String editToken,
    required String walletUserHash,
    CancelToken? cancelToken,
  }) {
    return _mainClient.patch(
      '/api/review/$reviewId/edit-token',
      body: {'edit_token': editToken, 'wallet_user_hash': walletUserHash},
      cancelToken: cancelToken,
      // decode callback intentionally ignores the response body.
      decode: (_) {},
    );
  }
}
