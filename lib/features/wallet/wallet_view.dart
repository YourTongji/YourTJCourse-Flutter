import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            padding: const EdgeInsets.all(16),
            children: [
              // Balance card
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.primary.withValues(alpha: 0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('积分余额', style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      )),
                      const SizedBox(height: 8),
                      Text(
                        '${data.balance}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (data.totalEarned != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '累计获得 ${data.totalEarned} 积分',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Today's activity
              if (today != null) ...[
                Text('今日活动', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
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
                      Text('如何获得积分？', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
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
