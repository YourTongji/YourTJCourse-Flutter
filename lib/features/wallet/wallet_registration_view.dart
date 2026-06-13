import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:yourtjcourse_flutter/services/log_writer.dart';

import '../../shared/widgets/credit_webview_page.dart';
import '../../domain/models/mnemonic_helper.dart';
import '../../domain/models/wallet.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// Wallet registration: opens [credit.yourtj.de] in an in-app WebView for
/// registration/login, or restores from a mnemonic phrase.
class WalletRegistrationView extends ConsumerStatefulWidget {
  const WalletRegistrationView({super.key});

  @override
  ConsumerState<WalletRegistrationView> createState() =>
      _WalletRegistrationViewState();
}

class _WalletRegistrationViewState
    extends ConsumerState<WalletRegistrationView> {
  final _mnemonicCtrl = TextEditingController();
  var _busy = false;
  String? _error;
  var _restoreMode = false;

  @override
  void dispose() {
    _mnemonicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_restoreMode ? '恢复钱包' : '注册钱包'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'YourTJ Credit',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '去中心化积分钱包',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (_restoreMode) _buildRestoreForm(theme, scheme)
              else ...[
                // Open credit.yourtj.de button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _openCreditWebView,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.open_in_browser),
                    label: Text(_busy ? '加载中…' : '在 Web 端注册 / 登录'),
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Restore link
                Center(
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _restoreMode = true),
                    icon: const Icon(Icons.restore_page, size: 18),
                    label: const Text('已有助记词？点击恢复'),
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Restore form ─────────────────────────────────────────────────

  Widget _buildRestoreForm(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _mnemonicCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入 3 个助记词，用空格或连字符分隔',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : _restore,
            child: Text(_busy ? '恢复中…' : '恢复钱包'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _restoreMode = false;
            _error = null;
          }),
          child: const Text('返回注册'),
        ),
      ],
    );
  }

  // ── Open credit WebView ──────────────────────────────────────────

  Future<void> _openCreditWebView() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final walletAvailable = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreditWebViewPage(registerMode: true)),
      );

      if (walletAvailable == true && mounted) {
        LogWriter.instance.write({
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'info',
          'type': 'lifecycle',
          'event': 'wallet_login',
          'message': '钱包登录成功',
        });
        // Invalidate wallet provider so the parent /wallet page picks up
        // the freshly saved credentials when it re-renders.
        ref.invalidate(walletProvider);
        // Navigate to /wallet via GoRouter pushReplacement in the next frame
        // to avoid race conditions and the Bad state: No element crash.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pushReplacement('/wallet');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Restore from mnemonic ────────────────────────────────────────

  Future<void> _restore() async {
    final phrase = _mnemonicCtrl.text.trim();
    if (phrase.isEmpty) {
      setState(() => _error = '请输入助记词');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = MnemonicHelper.restore(phrase);

      final repo = ref.read(walletRepositoryProvider);
      try {
        await repo.fetchWallet(result.userHash);
      } catch (e) {
        // Only auto-register on confirmed not-found (404).
        if (e is DioException && e.response?.statusCode == 404) {
          await repo.registerWallet(
            WalletCredentials(
              mnemonic: result.mnemonic,
              userHash: result.userHash,
              userSecret: result.userSecret,
            ),
          );
        } else {
          rethrow;
        }
      }

      await ref.read(walletProvider.notifier).persistCredentials(
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
      setState(
        () => _error =
            '恢复失败：${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
