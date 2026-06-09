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
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            _WalletCardSkeleton(),
            SizedBox(height: 20),
            _ActivitySkeleton(),
            SizedBox(height: 16),
            _InfoSkeleton(),
          ],
        ),
        error: (error, _) =>
            ErrorState(message: error.toString(), onRetry: () => ref.invalidate(walletProvider)),
        data: (data) {
          final hasWallet = data.userHash.isNotEmpty;
          if (!hasWallet) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('钱包初始化失败', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(walletProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          final summary = data.summary;
          final today = summary?.today;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Wallet card
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
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset('assets/images/app_logo.png',
                            width: 60, height: 60, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('积分余额',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onPrimaryContainer)),
                            const SizedBox(height: 4),
                            Text('${data.balance}',
                                style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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

// ─── Shimmer animation ───────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerAnim = Tween<Alignment>(
      // Sweeps the highlight band from left edge (-1.0) to right edge (+1.0)
      // in Alignment coordinates across the widget width.
      begin: const Alignment(-2.5, 0.0),
      end: const Alignment(-0.5, 0.0),
    ).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final al = _shimmerAnim.value;
            return LinearGradient(
              begin: al,
              end: Alignment(al.x + 3.0, 0.0),
              colors: const [
                Color(0x00000000), // transparent
                Color(0x00000000), // transparent
                Color(0x33FFFFFF), // shimmer highlight (20% white)
                Color(0x00000000), // transparent
                Color(0x00000000), // transparent
              ],
              stops: [0.0, 0.4, 0.5, 0.6, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcOver,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

// ─── Skeleton widgets ────────────────────────────────────────────────

class _WalletCardSkeleton extends StatelessWidget {
  const _WalletCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base, borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            ClipOval(
              child: _ShimmerBox(width: 60, height: 60, borderRadius: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 60, height: 12),
                  const SizedBox(height: 8),
                  _ShimmerBox(width: 120, height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerBox(width: 80, height: 18),
        const SizedBox(height: 12),
        for (var i = 0; i < 2; i++) ...[
          Row(children: [
            _ShimmerBox(width: 18, height: 18),
            const SizedBox(width: 8),
            Expanded(child: _ShimmerBox(width: double.infinity, height: 16)),
            const SizedBox(width: 8),
            _ShimmerBox(width: 40, height: 16),
          ]),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _InfoSkeleton extends StatelessWidget {
  const _InfoSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: base, borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 100, height: 16),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++) ...[
              Row(children: [
                _ShimmerBox(width: 16, height: 16),
                const SizedBox(width: 6),
                _ShimmerBox(width: 180, height: 14),
              ]),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Supporting widgets ──────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final int value;

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
          Text('+$value', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary)),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text});
  final IconData icon; final String text;

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
