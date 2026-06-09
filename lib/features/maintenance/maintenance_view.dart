import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/runtime_state.dart';
import 'maintenance_provider.dart';

/// Full-screen maintenance overlay shown when the backend is in maintenance mode.
///
/// Matches iOS `MaintenanceContentView` — displays title, message, estimated
/// downtime, and optional progress steps. Supports pull-to-refresh so users
/// can recheck when maintenance ends.
class MaintenanceView extends ConsumerWidget {
  const MaintenanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(maintenanceStateProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 56, color: scheme.error),
                  const SizedBox(height: 16),
                  Text('无法连接服务器',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('请检查网络连接后重试',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(maintenanceStateProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (maintenance) {
            if (!maintenance.enabled) return const SizedBox.shrink();

            final config = maintenance.config;
            final downtime = config?.estimatedDowntime;
            final progress = config?.progress;
            return RefreshIndicator(
              onRefresh: () => ref.read(maintenanceStateProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                children: [
                  const SizedBox(height: 20),

                  // ── Icon ──────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(Icons.construction_rounded,
                        size: 48, color: scheme.tertiary),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────
                  Text(
                    config?.title ?? '系统维护中',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Message ───────────────────────────
                  Text(
                    config?.message ?? '我们正在对系统进行升级维护，期间部分功能暂时不可用。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Estimated downtime ────────────────
                  if (downtime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 20, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '预计耗时：$downtime',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (downtime != null) const SizedBox(height: 20),

                  // ── Progress steps ────────────────────
                  if (progress != null && progress.isNotEmpty)
                    _ProgressSteps(steps: progress, theme: theme, scheme: scheme),

                  const SizedBox(height: 32),

                  // ── Auto-recovery hint ────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: scheme.secondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '维护完成后将自动恢复，您可以下拉刷新检查状态',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Pull to refresh indicator ─────────
                  Center(
                    child: Text(
                      '↓ 下拉刷新检查状态',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Progress steps widget ──────────────────────────────────────────

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({
    required this.steps,
    required this.theme,
    required this.scheme,
  });

  final List<MaintenanceProgressItem> steps;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('维护进度',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...List.generate(steps.length, (i) {
          final step = steps[i];
          final isLast = i == steps.length - 1;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline column
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: step.done ? 22 : (step.current ? 22 : 16),
                        height: step.done ? 22 : (step.current ? 22 : 16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: step.done
                              ? scheme.primary
                              : (step.current
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest),
                          border: !step.done && !step.current
                              ? Border.all(color: scheme.outlineVariant)
                              : null,
                        ),
                        child: step.done
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : (step.current
                                ? SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.primary,
                                    ),
                                  )
                                : null),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: step.done
                                ? scheme.primary.withValues(alpha: 0.3)
                                : scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Label
                Padding(
                  padding: EdgeInsets.only(top: step.done || step.current ? 2 : 0, bottom: isLast ? 0 : 20),
                  child: Text(
                    step.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: step.current ? FontWeight.w700 : FontWeight.w500,
                      color: step.done
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
