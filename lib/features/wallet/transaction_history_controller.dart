import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transaction.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// State for the paginated transaction history list.
class TransactionHistoryState {
  const TransactionHistoryState({
    required this.transactions,
    required this.hasMore,
    required this.currentPage,
    this.isLoading = false,
    this.error,
  });

  final List<Transaction> transactions;
  final bool hasMore;
  final int currentPage;
  final bool isLoading;
  final String? error;

  TransactionHistoryState copyWith({
    List<Transaction>? transactions,
    bool? hasMore,
    int? currentPage,
    bool? isLoading,
    String? error,
  }) {
    return TransactionHistoryState(
      transactions: transactions ?? this.transactions,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final transactionHistoryProvider = AsyncNotifierProvider.autoDispose<
    TransactionHistoryController, TransactionHistoryState>(
  TransactionHistoryController.new,
);

class TransactionHistoryController
    extends AsyncNotifier<TransactionHistoryState> {
  @override
  Future<TransactionHistoryState> build() async {
    return _fetchPage(1);
  }

  Future<TransactionHistoryState> _fetchPage(int page) async {
    final wallet = ref.read(walletProvider).value;
    if (wallet == null || !wallet.hasWallet) {
      return const TransactionHistoryState(
        transactions: [],
        hasMore: false,
        currentPage: 1,
      );
    }

    try {
      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.fetchTransactionHistory(
        wallet.userHash,
        page: page,
        limit: 20,
      );
      return TransactionHistoryState(
        transactions: result.transactions,
        hasMore: result.hasMore,
        currentPage: result.page,
      );
    } catch (e) {
      throw Exception('加载交易记录失败：$e');
    }
  }

  /// Load the next page of transactions (appended).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoading) return;

    state = AsyncData(current.copyWith(isLoading: true));
    try {
      final wallet = ref.read(walletProvider).value;
      if (wallet == null || !wallet.hasWallet) return;

      final repo = ref.read(walletRepositoryProvider);
      final result = await repo.fetchTransactionHistory(
        wallet.userHash,
        page: current.currentPage + 1,
        limit: 20,
      );
      state = AsyncData(TransactionHistoryState(
        transactions: [...current.transactions, ...result.transactions],
        hasMore: result.hasMore,
        currentPage: result.page,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isLoading: false));
    }
  }

  /// Refresh from page 1.
  Future<void> refresh() async {
    final state = await _fetchPage(1);
    this.state = AsyncData(state);
  }
}
