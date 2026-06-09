import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/cancel_token_scope.dart';
import '../../domain/models/wallet.dart';
import 'wallet_repository.dart';

/// Combined wallet state: basic wallet + optional summary.
class WalletState {
  const WalletState({required this.userHash, this.balance = 0, this.summary});

  factory WalletState.fromWallet(CreditWallet w) =>
      WalletState(userHash: w.userHash, balance: w.balance);

  final String userHash;
  final int balance;
  final WalletSummary? summary;

  bool get hasWallet => userHash.isNotEmpty;
}

final walletProvider =
    AsyncNotifierProvider.autoDispose<WalletController, WalletState>(
      WalletController.new,
    );

class WalletController extends AsyncNotifier<WalletState> {
  static const _mnemonicKey = 'de.yourtj.course.wallet.mnemonic';
  static const _hashKey = 'de.yourtj.course.wallet.userHash';
  static const _secretKey = 'de.yourtj.course.wallet.userSecret';

  final _secureStorage = const FlutterSecureStorage();
  late WalletRepository _repository;

  @override
  Future<WalletState> build() async {
    _repository = ref.watch(walletRepositoryProvider);
    final cancelToken = scopedCancelToken(ref);

    final savedHash = await _secureStorage.read(key: _hashKey);

    if (savedHash == null || savedHash.isEmpty) {
      // First launch — generate credentials and register.
      final creds = WalletCredentials.generate();
      final wallet = await _repository.registerWallet(creds, cancelToken: cancelToken);
      await _secureStorage.write(key: _mnemonicKey, value: creds.mnemonic);
      await _secureStorage.write(key: _hashKey, value: creds.userHash);
      await _secureStorage.write(key: _secretKey, value: creds.userSecret);
      return WalletState(userHash: creds.userHash, balance: wallet.balance);
    }

    // Fetch wallet, then summary in the background.
    final wallet = await _repository.fetchWallet(savedHash, cancelToken: cancelToken);
    final summary = await _repository.fetchSummary(savedHash, cancelToken: cancelToken);
    return WalletState(userHash: wallet.userHash, balance: wallet.balance, summary: summary);
  }

  /// Persisted wallet credentials.
  Future<WalletCredentials?> loadCredentials() async {
    final mnemonic = await _secureStorage.read(key: _mnemonicKey);
    final hash = await _secureStorage.read(key: _hashKey);
    final secret = await _secureStorage.read(key: _secretKey);
    if (hash == null || secret == null) return null;
    return WalletCredentials(mnemonic: mnemonic ?? '', userHash: hash, userSecret: secret);
  }
}
