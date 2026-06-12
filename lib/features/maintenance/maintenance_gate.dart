import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/runtime_state.dart';
import 'runtime_state_controller.dart';

/// Full maintenance overlay — simplified icons, timeline progress,
/// pull-to-refresh, matching dev branch design.
class MaintenanceGate extends ConsumerWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtimeAsync = ref.watch(runtimeStateProvider);
    final runtime = runtimeAsync.value;
    final isMaintenance = runtime?.maintenance.enabled ?? false;

    if (!isMaintenance) return child;

    final config = runtime!.maintenance.config;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.read(runtimeStateProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            children: [
              const SizedBox(height: 20),
              // Icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.construction_rounded, size: 44, color: scheme.tertiary),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                config?.title ?? '系统维护中',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Message
              Text(
                config?.message ?? '我们正在对系统进行升级维护，期间部分功能暂时不可用。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              // Estimated downtime
              if (config?.eta != null)
                _infoBox(Icons.schedule_rounded, '预计恢复：${config!.eta}', scheme, theme),
              if (config?.eta != null) const SizedBox(height: 20),
              // Progress steps with timeline
              if (config?.progress != null && config!.progress!.isNotEmpty)
                _ProgressSteps(steps: config.progress!, scheme: scheme, theme: theme),
              const SizedBox(height: 24),
              // Pull-to-refresh hint
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
        ),
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, ColorScheme scheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ProgressSteps extends StatelessWidget {
  const _ProgressSteps({required this.steps, required this.scheme, required this.theme});
  final List<MaintenanceProgressItem> steps;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('维护进度', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (int i = 0; i < steps.length; i++) _step(i, steps[i], i == steps.length - 1),
      ],
    );
  }

  Widget _step(int index, MaintenanceProgressItem step, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(children: [
              Container(
                width: step.done ? 22 : (step.active ? 22 : 16),
                height: step.done ? 22 : (step.active ? 22 : 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.done
                      ? scheme.primary
                      : step.active
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                  border: !step.done && !step.active
                      ? Border.all(color: scheme.outlineVariant)
                      : null,
                ),
                child: step.done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : step.active
                        ? SizedBox(width: 10, height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                        : null,
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
            ]),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: step.done || step.active ? 2 : 0, bottom: isLast ? 0 : 20),
            child: Text(step.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: step.active ? FontWeight.w700 : FontWeight.w500,
                color: step.done ? scheme.onSurface : scheme.onSurfaceVariant,
              )),
          ),
        ],
      ),
    );
  }
}
