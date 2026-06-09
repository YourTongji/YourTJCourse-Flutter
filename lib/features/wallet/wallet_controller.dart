import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../domain/models/wallet.dart';
import 'wallet_repository.dart';

final walletProvider =
    AsyncNotifierProvider.autoDispose<WalletController, CreditWallet>(
      WalletController.new,
    );

class WalletController extends AsyncNotifier<CreditWallet> {
  static const _mnemonicKey = 'de.yourtj.course.wallet.mnemonic';
  static const _hashKey = 'de.yourtj.course.wallet.userHash';
  static const _secretKey = 'de.yourtj.course.wallet.userSecret';

  late WalletRepository _repository;
  late CancelToken _cancelToken;

  @override
  Future<CreditWallet> build() async {
    _repository = ref.watch(walletRepositoryProvider);
    _cancelToken = scopedCancelToken(ref);

    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_hashKey);

    if (savedHash == null || savedHash.isEmpty) {
      // First launch — register a new wallet.
      try {
        final reg = await _repository.registerWallet(
          cancelToken: _cancelToken,
        );
        await prefs.setString(_mnemonicKey, reg.mnemonic);
        await prefs.setString(_hashKey, reg.userHash);
        await prefs.setString(_secretKey, reg.userSecret);
        return CreditWallet(userHash: reg.userHash, balance: 0);
      } catch (_) {
        return const CreditWallet(userHash: '', balance: 0);
      }
    }

    // Return wallet with balance from backend.
    try {
      return await _repository.getWallet(
        userHash: savedHash,
        cancelToken: _cancelToken,
      );
    } catch (_) {
      return CreditWallet(userHash: savedHash, balance: 0);
    }
  }

  /// Persisted wallet credentials.
  Future<WalletCredentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final mnemonic = prefs.getString(_mnemonicKey);
    final hash = prefs.getString(_hashKey);
    final secret = prefs.getString(_secretKey);
    if (hash == null || secret == null) return null;
    return WalletCredentials(
      mnemonic: mnemonic ?? '',
      userHash: hash,
      userSecret: secret,
    );
  }
}
