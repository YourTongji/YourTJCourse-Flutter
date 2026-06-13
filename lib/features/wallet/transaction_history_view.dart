import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transaction.dart';
import '../../shared/widgets/app_states.dart';
import 'transaction_history_controller.dart';
import 'wallet_controller.dart';

/// Paginated transaction history page for the wallet.
class TransactionHistoryView extends ConsumerStatefulWidget {
  const TransactionHistoryView({super.key});

  @override
  ConsumerState<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends ConsumerState<TransactionHistoryView> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(transactionHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('交易记录')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(transactionHistoryProvider),
        ),
        data: (data) {
          if (data.transactions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('暂无交易记录',
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final wallet = ref.watch(walletProvider).value;
          final userHash = wallet?.userHash ?? '';

          return RefreshIndicator(
            onRefresh: () => ref.read(transactionHistoryProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: data.transactions.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= data.transactions.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final tx = data.transactions[index];
                final isCredit = tx.isCredit(userHash);
                final isDebit = tx.isDebit(userHash);
                return _TransactionTile(
                  transaction: tx,
                  isCredit: isCredit,
                  isDebit: isDebit,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.isCredit,
    required this.isDebit,
  });

  final Transaction transaction;
  final bool isCredit;
  final bool isDebit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final icon = _iconForType(transaction.typeName);
    final timestamp = _formatTime(transaction.createdAtDt);
    final amountStr = isCredit ? '+${transaction.amount}' : '-${transaction.amount}';
    final amountColor = isCredit ? scheme.primary : scheme.error;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCredit
              ? scheme.primaryContainer.withValues(alpha: 0.5)
              : scheme.errorContainer.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: isCredit ? scheme.primary : scheme.error),
      ),
      title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        transaction.typeDisplayName,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amountStr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: amountColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(timestamp,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'task_reward' || 'system_reward' => Icons.emoji_events_outlined,
      'product_purchase' => Icons.shopping_bag_outlined,
      'transfer' => Icons.swap_horiz_rounded,
      'admin_adjust' => Icons.admin_panel_settings_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.month}/${dt.day}';
  }
}
