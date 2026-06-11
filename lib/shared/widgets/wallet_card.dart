import 'package:flutter/material.dart';

/// Display mode for [WalletCard].
enum WalletCardMode { full, compact, inline }

/// A Material 3 wallet balance card inspired by fluxdo's `CdkBalanceCard`.
///
/// Supports three display modes:
/// - `full` (default): Gradient card with decorative background, for wallet page
/// - `compact`: Flat card with minimal styling, for profile/preview
/// - `inline`: Row-only without card wrapper, for embedding in lists
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.balance,
    this.mode = WalletCardMode.full,
    this.label = '积分余额',
    this.icon,
    this.onTap,
    this.onRefresh,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
  });

  final int balance;
  final WalletCardMode mode;
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final bool isError;
  final String? errorMessage;

  // ── Full mode ─────────────────────────────────────────────────

  Widget _buildFull(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shadowColor: scheme.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative background
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: icon ??
                              Image.asset('assets/images/app_logo.png',
                                  width: 24, height: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'YourTJ Wallet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          )
                        else if (onRefresh != null)
                          GestureDetector(
                            onTap: onRefresh,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.refresh_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isError)
                      _buildErrorContent(theme)
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$balance',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 36,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '积分',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compact mode ──────────────────────────────────────────────

  Widget _buildCompact(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: isError
          ? scheme.errorContainer.withValues(alpha: 0.3)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError
              ? scheme.error.withValues(alpha: 0.3)
              : scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isError
                      ? scheme.error.withValues(alpha: 0.1)
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: isError
                    ? Icon(Icons.error_outline_rounded,
                        size: 20, color: scheme.error)
                    : (icon ??
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 20, color: scheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                    if (isError)
                      Text(errorMessage ?? '加载失败',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.error))
                    else
                      Text('$balance 积分',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: scheme.outline.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Inline mode ───────────────────────────────────────────────

  Widget _buildInline(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isError
                      ? scheme.error.withValues(alpha: 0.1)
                      : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: isError
                    ? Icon(Icons.error_outline_rounded, size: 20, color: scheme.error)
                    : (icon ??
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 20, color: scheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                    if (isError)
                      Text(errorMessage ?? '加载失败',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600, color: scheme.error))
                    else
                      Text('$balance',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          errorMessage ?? '加载失败',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        if (onRefresh != null)
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (mode) {
      WalletCardMode.full => _buildFull(context, theme),
      WalletCardMode.compact => _buildCompact(context, theme),
      WalletCardMode.inline => _buildInline(context, theme),
    };
  }
}

