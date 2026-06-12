import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../wallet/wallet_controller.dart';
import 'theme_provider.dart';

/// Full theme + wallet settings matching fluxdo's appearance page layout.
class ThemeSettingsView extends ConsumerWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('外观与钱包')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader(title: '主题模式', icon: Icons.brightness_6_outlined),
          Card(
            child: Column(
              children: [
                _ModeTile(
                  label: '跟随系统',
                  icon: Icons.brightness_auto_rounded,
                  selected: themeState.mode == ThemeMode.system,
                  onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system),
                ),
                _ModeTile(
                  label: '浅色',
                  icon: Icons.light_mode_rounded,
                  selected: themeState.mode == ThemeMode.light,
                  onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light),
                ),
                _ModeTile(
                  label: '深色',
                  icon: Icons.dark_mode_rounded,
                  selected: themeState.mode == ThemeMode.dark,
                  onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _SectionHeader(title: '主题色', icon: Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ytjPresetColors.map((color) {
                  final isSelected = color.toARGB32() == themeState.seedColor.toARGB32();
                  return GestureDetector(
                    onTap: () => ref.read(themeProvider.notifier).setSeedColor(color),
                    child: Container(
                      width: 44, height: 44,
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
          const SizedBox(height: 20),

          _SectionHeader(title: '动态取色', icon: Icons.gradient_outlined),
          SwitchListTile(
            title: const Text('使用系统动态颜色'),
            subtitle: const Text('开启后自动跟随系统壁纸取色'),
            value: themeState.useDynamicColor,
            onChanged: (v) => ref.read(themeProvider.notifier).setUseDynamicColor(v),
          ),
          const SizedBox(height: 20),

          _SectionHeader(title: '色调变体', icon: Icons.color_lens_outlined),
          Card(
            child: Column(
              children: DynamicSchemeVariant.values.map((variant) {
                final sel = themeState.schemeVariant == variant;
                return ListTile(
                  title: Text(_variantLabel(variant)),
                  trailing: sel ? const Icon(Icons.check, size: 18) : null,
                  onTap: () => ref.read(themeProvider.notifier).setSchemeVariant(variant),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 28),

          _SectionHeader(title: '钱包', icon: Icons.account_balance_wallet_outlined),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded, color: scheme.error, size: 20),
              ),
              title: const Text('退出钱包'),
              subtitle: const Text('清除本地凭证，可用助记词恢复'),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
          const SizedBox(height: 32),
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

    const storage = FlutterSecureStorage();
    await storage.delete(key: 'de.yourtj.course.wallet.mnemonic');
    await storage.delete(key: 'de.yourtj.course.wallet.userHash');
    await storage.delete(key: 'de.yourtj.course.wallet.userSecret');

    ref.invalidate(walletProvider);
  }

  String _variantLabel(DynamicSchemeVariant v) => switch (v) {
    DynamicSchemeVariant.tonalSpot => 'Tonal Spot（默认）',
    DynamicSchemeVariant.fidelity => 'Fidelity（忠实）',
    DynamicSchemeVariant.monochrome => 'Monochrome（单色）',
    DynamicSchemeVariant.neutral => 'Neutral（中性）',
    DynamicSchemeVariant.vibrant => 'Vibrant（鲜艳）',
    DynamicSchemeVariant.expressive => 'Expressive（表现力）',
    DynamicSchemeVariant.content => 'Content（内容）',
    DynamicSchemeVariant.rainbow => 'Rainbow（彩虹）',
    DynamicSchemeVariant.fruitSalad => 'Fruit Salad（水果沙拉）',
  };
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTile({required this.label, required this.icon, required this.selected, required this.onTap});

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
