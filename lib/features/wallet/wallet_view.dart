import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';

import '../../shared/widgets/app_states.dart';
import 'wallet_controller.dart';

class WalletView extends ConsumerWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('钱包')),
      body: wallet.when(
        loading: () => const LoadingState(message: '正在加载钱包'),
        error: (error, _) =>
            ErrorState(message: error.toString(), onRetry: () => ref.invalidate(walletProvider)),
        data: (data) {
          final hasWallet = data.userHash.isNotEmpty;
          if (!hasWallet) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('钱包初始化失败，请重试', textAlign: TextAlign.center),
              ),
            );
          }
          final today = data.today;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Credit-card-style wallet card with app logo.
              CreditCardWidget(
                cardNumber: '${data.balance} 积分',
                expiryDate: '今日 +${data.totalEarned ?? 0}',
                cardHolderName: 'YourTJ Wallet',
                cvvCode: data.userHash.length > 6
                    ? data.userHash.substring(0, 6).toUpperCase()
                    : data.userHash,
                showBackView: false,
                obscureCardNumber: false,
                obscureCardCvv: false,
                isHolderNameVisible: true,
                isChipVisible: false,
                isSwipeGestureEnabled: false,
                cardBgColor: scheme.primaryContainer.withValues(alpha: 0.4),
                backgroundImage: 'assets/images/app_logo.png',
                frontCardBorder: Border.all(
                  color: scheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
                textStyle: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                onCreditCardWidgetChange: (_) {},
              ),
              const SizedBox(height: 20),

              // Today's activity
              if (today != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('今日活动',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                _ActivityRow(
                  icon: Icons.rate_review_outlined,
                  label: '评课奖励',
                  value: today.reviewReward,
                ),
                _ActivityRow(
                  icon: Icons.thumb_up_outlined,
                  label: '点赞待结算',
                  value: today.likePendingPoints,
                ),
                const SizedBox(height: 16),
              ],

              // Info card
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('如何获得积分？',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      _BenefitRow(icon: Icons.edit_note, text: '撰写课程评价 +10 积分'),
                      _BenefitRow(icon: Icons.thumb_up, text: '收到的点赞可获得额外积分'),
                      _BenefitRow(icon: Icons.edit, text: '编辑评价也可获得积分奖励'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text('+$value', style: TextStyle(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          )),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
