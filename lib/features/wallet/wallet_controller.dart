import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final _secureStorage = const FlutterSecureStorage();

  late WalletRepository _repository;
  late CancelToken _cancelToken;

  @override
  Future<CreditWallet> build() async {
    _repository = ref.watch(walletRepositoryProvider);
    _cancelToken = scopedCancelToken(ref);

    final savedHash = await _secureStorage.read(key: _hashKey);

    if (savedHash == null || savedHash.isEmpty) {
      // First launch — register a new wallet.
      final reg = await _repository.registerWallet(
        cancelToken: _cancelToken,
      );
      await _secureStorage.write(key: _mnemonicKey, value: reg.mnemonic);
      await _secureStorage.write(key: _hashKey, value: reg.userHash);
      await _secureStorage.write(key: _secretKey, value: reg.userSecret);
      return CreditWallet(userHash: reg.userHash, balance: 0);
    }

    // Return wallet with balance from backend.
    return _repository.getWallet(
      userHash: savedHash,
      cancelToken: _cancelToken,
    );
  }

  /// Persisted wallet credentials.
  Future<WalletCredentials?> loadCredentials() async {
    final mnemonic = await _secureStorage.read(key: _mnemonicKey);
    final hash = await _secureStorage.read(key: _hashKey);
    final secret = await _secureStorage.read(key: _secretKey);
    if (hash == null || secret == null) return null;
    return WalletCredentials(
      mnemonic: mnemonic ?? '',
      userHash: hash,
      userSecret: secret,
    );
  }
}
