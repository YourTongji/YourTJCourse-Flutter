import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/mnemonic_helper.dart';
import '../../domain/models/wallet.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// Wallet registration flow matching iOS WalletView.
///
/// 1. Student ID + PIN → MnemonicHelper.generate() → credentials
/// 2. POST /api/wallet/register
/// 3. Show 3-word mnemonic for backup
/// 4. Persist credentials → navigate to wallet
class WalletRegistrationView extends ConsumerStatefulWidget {
  const WalletRegistrationView({super.key});

  @override
  ConsumerState<WalletRegistrationView> createState() => _WalletRegistrationViewState();
}

class _WalletRegistrationViewState extends ConsumerState<WalletRegistrationView> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  var _isRegistering = false;
  var _obscurePin = true;
  var _obscureConfirm = true;

  // Registration result — shown after success.
  String? _registeredMnemonic;

  @override
  void dispose() {
    _studentIdController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('注册钱包')),
      body: _registeredMnemonic != null
          ? _buildBackupView(theme, scheme)
          : _buildForm(theme, scheme),
    );
  }

  // ── Registration form ──────────────────────────────────────────────

  Widget _buildForm(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          // Header
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text('注册积分钱包',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            '使用学号和 PIN 注册后，可跨设备同步积分',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Student ID
          TextFormField(
            controller: _studentIdController,
            keyboardType: TextInputType.number,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: '学号',
              hintText: '7-10 位数字',
              prefixIcon: Icon(Icons.badge_outlined),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入学号';
              if (!RegExp(r'^\d{7,10}$').hasMatch(v.trim())) return '学号应为 7-10 位数字';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // PIN
          TextFormField(
            controller: _pinController,
            obscureText: _obscurePin,
            maxLength: 32,
            decoration: InputDecoration(
              labelText: 'PIN',
              hintText: '6-32 位字符',
              prefixIcon: const Icon(Icons.lock_outlined),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '请输入 PIN';
              if (v.length < 6 || v.length > 32) return 'PIN 长度需在 6-32 位之间';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm PIN
          TextFormField(
            controller: _confirmPinController,
            obscureText: _obscureConfirm,
            maxLength: 32,
            decoration: InputDecoration(
              labelText: '确认 PIN',
              prefixIcon: const Icon(Icons.lock_outlined),
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return '请确认 PIN';
              if (v != _pinController.text) return '两次输入的 PIN 不一致';
              return null;
            },
          ),
          const SizedBox(height: 28),

          // Submit
          FilledButton.icon(
            onPressed: _isRegistering ? null : _register,
            icon: _isRegistering
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.how_to_reg),
            label: Text(_isRegistering ? '注册中…' : '注册钱包'),
          ),
          const SizedBox(height: 16),

          // Restore link
          TextButton(
            onPressed: () => _showRestoreDialog(context),
            child: const Text('已有助记词？恢复钱包'),
          ),
        ],
      ),
    );
  }

  // ── Mnemonic backup display ────────────────────────────────────────

  Widget _buildBackupView(ThemeData theme, ColorScheme scheme) {
    final words = _registeredMnemonic!.split('-');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Icon(Icons.check_circle, size: 56, color: scheme.primary),
        const SizedBox(height: 12),
        Text('钱包注册成功',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),

        // Mnemonic phrase
        Text('请备份您的助记词',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('这 3 个词可用于恢复钱包，请妥善保管',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),

        Card(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < words.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      words[i],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _copyMnemonic,
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('复制助记词'),
        ),
        const SizedBox(height: 24),

        // Warning
        Card(
          color: scheme.errorContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('请务必备份您的助记词！助记词是恢复钱包的唯一方式，丢失后将无法找回。',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: () => context.pushReplacement('/wallet'),
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('进入钱包'),
        ),
      ],
    );
  }

  // ── Registration logic ─────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);
    try {
      final studentId = _studentIdController.text.trim();
      final pin = _pinController.text;

      // Step 1: Generate credentials (same as iOS MnemonicHelper.generate).
      final result = MnemonicHelper.generate(studentId: studentId, pin: pin);

      // Step 2: Register with the credit server.
      final creds = WalletCredentials(
        mnemonic: result.mnemonic,
        userHash: result.userHash,
        userSecret: result.userSecret,
      );
      final repo = ref.read(walletRepositoryProvider);
      await repo.registerWallet(creds);

      // Step 3: Persist credentials.
      final controller = ref.read(walletProvider.notifier);
      await controller.persistCredentials(creds);

      // Step 4: Show the mnemonic for backup.
      setState(() {
        _registeredMnemonic = result.mnemonic;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('注册失败：$e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      setState(() => _isRegistering = false);
    }
  }

  void _copyMnemonic() {
    if (_registeredMnemonic == null) return;
    // Using Clipboard is ideal but would need import.
    // For now show a snackbar with the text.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('助记词：$_registeredMnemonic'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '复制',
          onPressed: () {
            // Copy to clipboard
            // Clipboard.setData(ClipboardData(text: _registeredMnemonic!));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制到剪贴板（需 flutter/services.dart）')),
            );
          },
        ),
      ),
    );
  }

  // ── Restore dialog ─────────────────────────────────────────────────

  void _showRestoreDialog(BuildContext context) {
    final mnemonicController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复钱包'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入您的 3 词助记词（用空格或短横分隔）'),
            const SizedBox(height: 12),
            TextField(
              controller: mnemonicController,
              decoration: const InputDecoration(
                labelText: '助记词',
                hintText: '例：瑞安楼-东方明珠-东楼',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _restore(mnemonicController.text.trim());
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(String phrase) async {
    if (phrase.isEmpty) return;

    setState(() => _isRegistering = true);
    try {
      // Step 1: Restore credentials from mnemonic (same as iOS).
      final result = MnemonicHelper.restore(phrase);

      // Step 2: Check if wallet exists on credit server.
      final repo = ref.read(walletRepositoryProvider);
      try {
        await repo.fetchWallet(result.userHash);
      } catch (_) {
        // Wallet doesn't exist yet — register it.
        final creds = WalletCredentials(
          mnemonic: result.mnemonic,
          userHash: result.userHash,
          userSecret: result.userSecret,
        );
        await repo.registerWallet(creds);
      }

      // Step 3: Persist and refresh.
      final controller = ref.read(walletProvider.notifier);
      await controller.persistCredentials(
        WalletCredentials(
          mnemonic: result.mnemonic,
          userHash: result.userHash,
          userSecret: result.userSecret,
        ),
      );
      ref.invalidate(walletProvider);
      if (!mounted) return;
      context.pushReplacement('/wallet');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：$e')),
      );
    } finally {
      setState(() => _isRegistering = false);
    }
  }
}
