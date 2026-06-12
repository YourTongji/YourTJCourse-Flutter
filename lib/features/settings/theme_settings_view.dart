import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../wallet/wallet_controller.dart';
import 'theme_provider.dart';

/// Theme color + wallet settings page.
class ThemeSettingsView extends ConsumerWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeStateProvider).value ??
        const ThemeState(mode: ThemeMode.system, seedColor: Color(0xFF036099));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('主题与钱包')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Theme mode ─────────────────────────────────
          Text('显示模式', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ModeTile(
                  label: '跟随系统',
                  icon: Icons.brightness_auto_rounded,
                  selected: themeState.mode == ThemeMode.system,
                  onTap: () => ref.read(themeStateProvider.notifier).setMode(ThemeMode.system),
                ),
                _ModeTile(
                  label: '浅色',
                  icon: Icons.light_mode_rounded,
                  selected: themeState.mode == ThemeMode.light,
                  onTap: () => ref.read(themeStateProvider.notifier).setMode(ThemeMode.light),
                ),
                _ModeTile(
                  label: '深色',
                  icon: Icons.dark_mode_rounded,
                  selected: themeState.mode == ThemeMode.dark,
                  onTap: () => ref.read(themeStateProvider.notifier).setMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Seed color ─────────────────────────────────
          Text('主题色', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ytjPresetColors.map((color) {
                  final isSelected = color.toARGB32() == (themeState.seedColor.toARGB32());
                  return GestureDetector(
                    onTap: () => ref.read(themeStateProvider.notifier).setSeedColor(color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: scheme.onSurface, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Wallet section ─────────────────────────────
          Text('钱包', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.logout_rounded, color: scheme.error, size: 20),
                  ),
                  title: const Text('退出钱包'),
                  subtitle: const Text('清除本地钱包凭证'),
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出钱包'),
        content: const Text('将清除本地保存的钱包凭证，如需恢复请使用助记词。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('确认退出')),
        ],
      ),
    );
    if (confirmed != true) return;

    // Clear stored credentials.
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'de.yourtj.course.wallet.mnemonic');
    await storage.delete(key: 'de.yourtj.course.wallet.userHash');
    await storage.delete(key: 'de.yourtj.course.wallet.userSecret');

    ref.invalidate(walletProvider);
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, size: 18) : null,
      onTap: onTap,
    );
  }
}
