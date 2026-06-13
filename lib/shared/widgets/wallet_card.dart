import 'package:flutter/material.dart';

import 'credit_webview_page.dart';

/// Display mode for [WalletCard].
enum WalletCardMode { full, compact, inline }

/// A wallet balance card with gradient/compact/inline display modes.
///
/// - `full` (default): Gradient card with decorative background, for wallet page
/// - `compact`: Flat card with minimal styling, for profile/preview
/// - `inline`: Row-only without card wrapper, for embedding in lists
///
/// Tapping opens [credit.yourtj.de] in the device browser.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.balance,
    this.mode = WalletCardMode.full,
    this.label = '积分余额',
    this.icon,
    this.dailyIncome,
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
  final int? dailyIncome;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final bool isError;
  final String? errorMessage;

  // ── Full mode ─────────────────────────────────────────────────

  void _openCreditUrl(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditWebViewPage()),
    );
  }

  Widget _buildFull(BuildContext context, ThemeData theme) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap ?? () => _openCreditUrl(context),
      child: Card(
        elevation: 8,
        shadowColor: scheme.primary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary],
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset('assets/images/app_logo.png',
                                    width: 24, height: 24, fit: BoxFit.cover),
                              ),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onRefresh != null && !isLoading)
                              GestureDetector(
                                onTap: onRefresh,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            if (isLoading)
                              const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white70,
                                ),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 22,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isError)
                      _buildErrorContent(theme)
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          if (dailyIncome != null && dailyIncome! > 0) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    color: Colors.greenAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '今日 +$dailyIncome',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          Icon(Icons.touch_app_rounded,
                              size: 12, color: Colors.white.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(
                            '轻触进入',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
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
        onTap: onTap ?? () => _openCreditUrl(context),
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
              if (dailyIncome != null && dailyIncome! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '+$dailyIncome',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
        onTap: onTap ?? () => _openCreditUrl(context),
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

