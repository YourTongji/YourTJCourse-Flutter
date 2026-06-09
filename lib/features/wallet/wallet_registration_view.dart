import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/credit_wordlist.dart';
import '../../domain/models/mnemonic_helper.dart';
import '../../domain/models/wallet.dart';
import 'wallet_controller.dart';
import 'wallet_repository.dart';

/// Wallet registration flow matching iOS.
///
/// Steps:
///   1. Student ID + PIN → MnemonicHelper.generate() → credentials
///   2. POST /api/wallet/register → persist
///   3. Show 3-word mnemonic for backup
///   4. Navigate to wallet
///
/// Also supports restoring from an existing mnemonic phrase via [/wallet/register?restore].
class WalletRegistrationView extends ConsumerStatefulWidget {
  const WalletRegistrationView({super.key});

  @override
  ConsumerState<WalletRegistrationView> createState() => _WalletRegistrationViewState();
}

class _WalletRegistrationViewState extends ConsumerState<WalletRegistrationView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _mnemonicCtrl = TextEditingController();
  var _obscurePin = true;
  var _obscureConfirm = true;
  var _busy = false;
  String? _error;

  // Step state: null=register, 'backup', 'restore'
  String? _step;
  String? _mnemonic;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _mnemonicCtrl.dispose();
    _pulseCtrl.dispose();
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
          title: Text(_step == 'restore' ? '恢复钱包' : '注册钱包'),
          leading: _step != null && _step != 'restore'
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() { _step = null; _mnemonic = null; }),
                )
              : null,
        ),
        body: _buildBody(theme, scheme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme scheme) {
    if (_step == 'restore') return _buildRestoreView(theme, scheme);
    if (_step == 'backup') return _buildBackupView(theme, scheme);

    // ── Registration ─────────────────────────────────────────
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            // ── Hero header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.account_balance_wallet_outlined,
                        size: 40, color: scheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text('注册积分钱包',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    '使用学号和 PIN 创建您的积分钱包，\n跨设备同步，获得评价奖励',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // ── Error banner ────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: scheme.error),
                      onPressed: () => setState(() => _error = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // ── Student ID ──────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('学号', style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _studentIdCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      style: const TextStyle(fontSize: 18, letterSpacing: 2),
                      decoration: const InputDecoration(
                        hintText: '7-10 位数字',
                        prefixIcon: Icon(Icons.badge_outlined),
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '请输入学号';
                        if (!RegExp(r'^\d{7,10}$').hasMatch(v.trim())) return '学号应为 7-10 位数字';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── PIN ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('PIN', style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(
                          '${_pinCtrl.text.length}/32',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _pinCtrl,
                      obscureText: _obscurePin,
                      maxLength: 32,
                      style: const TextStyle(fontSize: 18, letterSpacing: 2),
                      decoration: InputDecoration(
                        hintText: '6-32 位字符',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请输入 PIN';
                        if (v.length < 6) return 'PIN 至少 6 位字符';
                        return null;
                      },
                    ),
                    // Strength indicator
                    const SizedBox(height: 4),
                    _PinStrengthBar(pin: _pinCtrl.text),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Confirm PIN ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('确认 PIN', style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _confirmPinCtrl,
                      obscureText: _obscureConfirm,
                      maxLength: 32,
                      style: const TextStyle(fontSize: 18, letterSpacing: 2),
                      decoration: InputDecoration(
                        hintText: '再次输入 PIN',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        counterText: '',
                        border: InputBorder.none,
                        filled: false,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '请确认 PIN';
                        if (v != _pinCtrl.text) return '两次输入的 PIN 不一致';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : _register,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.how_to_reg),
                label: Text(_busy ? '注册中…' : '注册钱包'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Restore link ─────────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : () => setState(() => _step = 'restore'),
                icon: const Icon(Icons.restore_page, size: 18),
                label: const Text('已有助记词？点击恢复'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Mnemonic backup ────────────────────────────────────────────────

  Widget _buildBackupView(ThemeData theme, ColorScheme scheme) {
    final words = _mnemonic!.split('-');

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        // ── Success icon ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 52, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text('钱包注册成功',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                '请立即备份您的助记词，这是恢复钱包的唯一方式',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),

        // ── Word cards with numbers ──────────────────────
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.abc, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text('助记词（3 个词）',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                // Numbered word chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < words.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _WordChip(index: i + 1, word: words[i], primary: scheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Copy button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyMnemonic,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制助记词'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Warning ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('请务必保管好助记词',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.error,
                        )),
                    const SizedBox(height: 3),
                    Text('助记词是恢复钱包的唯一凭证，YourTJ 无法为您找回。\n建议截图保存或抄写在纸上。',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Enter wallet ─────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => context.pushReplacement('/wallet'),
            icon: const Icon(Icons.account_balance_wallet_rounded),
            label: const Text('进入钱包'),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Restore view ──────────────────────────────────────────────────

  Widget _buildRestoreView(ThemeData theme, ColorScheme scheme) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.restore_page_rounded, size: 40, color: scheme.tertiary),
                ),
                const SizedBox(height: 16),
                Text('恢复钱包',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('输入您备份的 3 词助记词，恢复积分钱包',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),

          // Error banner
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: scheme.error),
                    onPressed: () => setState(() => _error = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

          // Mnemonic input
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('助记词', style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _mnemonicCtrl,
                    autofocus: true,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 18, letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: '例：瑞安楼 东方明珠 东楼',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.abc_outlined),
                      ),
                      border: InputBorder.none,
                      filled: false,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: IconButton(
                          icon: const Icon(Icons.paste_rounded),
                          tooltip: '粘贴',
                          onPressed: _pasteMnemonic,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 4),
                  Text('用空格或短横分隔 3 个词',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hint word list
          if (_mnemonicCtrl.text.isNotEmpty)
            _buildWordSuggestions(theme, scheme),

          const SizedBox(height: 24),

          // Restore button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _restore,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.restore_page_rounded),
              label: Text(_busy ? '恢复中…' : '恢复钱包'),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Back to register
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _step = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回注册'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSuggestions(ThemeData theme, ColorScheme scheme) {
    final input = _mnemonicCtrl.text.trim();
    final parts = input.split(RegExp(r'[\s\-]+'));
    final lastPart = parts.isNotEmpty ? parts.last : '';

    if (lastPart.isEmpty) return const SizedBox.shrink();

    final matches = CreditWordlist.words
        .where((w) => w.startsWith(lastPart))
        .take(8)
        .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: matches.map((w) {
          final isSelected = parts.contains(w);
          return FilterChip(
            label: Text(w, style: const TextStyle(fontSize: 13)),
            onSelected: isSelected ? null : (_) {
              final rest = parts.sublist(0, parts.length - 1);
              rest.add(w);
              _mnemonicCtrl.text = rest.join(' ');
              _mnemonicCtrl.selection = TextSelection.collapsed(offset: _mnemonicCtrl.text.length);
            },
            selected: isSelected,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _busy = true; _error = null; });
    try {
      final result = MnemonicHelper.generate(
        studentId: _studentIdCtrl.text.trim(),
        pin: _pinCtrl.text,
      );

      final creds = WalletCredentials(
        mnemonic: result.mnemonic,
        userHash: result.userHash,
        userSecret: result.userSecret,
      );
      await ref.read(walletRepositoryProvider).registerWallet(creds);
      await ref.read(walletProvider.notifier).persistCredentials(creds);

      HapticFeedback.heavyImpact();
      setState(() { _mnemonic = result.mnemonic; _step = 'backup'; });
    } catch (e) {
      setState(() => _error = '注册失败：${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final phrase = _mnemonicCtrl.text.trim();
    if (phrase.isEmpty) {
      setState(() => _error = '请输入助记词');
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      final result = MnemonicHelper.restore(phrase);

      final repo = ref.read(walletRepositoryProvider);
      try {
        await repo.fetchWallet(result.userHash);
      } catch (_) {
        await repo.registerWallet(WalletCredentials(
          mnemonic: result.mnemonic,
          userHash: result.userHash,
          userSecret: result.userSecret,
        ));
      }

      await ref.read(walletProvider.notifier).persistCredentials(
        WalletCredentials(
          mnemonic: result.mnemonic,
          userHash: result.userHash,
          userSecret: result.userSecret,
        ),
      );
      ref.invalidate(walletProvider);

      HapticFeedback.heavyImpact();
      if (!mounted) return;
      context.pushReplacement('/wallet');
    } catch (e) {
      setState(() => _error = '恢复失败：${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _copyMnemonic() {
    if (_mnemonic == null) return;
    Clipboard.setData(ClipboardData(text: _mnemonic!));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('助记词已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: '确定',
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Future<void> _pasteMnemonic() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _mnemonicCtrl.text = data!.text!;
      _mnemonicCtrl.selection = TextSelection.collapsed(offset: data.text!.length);
    }
  }
}

// ── PIN strength bar ────────────────────────────────────────────────

class _PinStrengthBar extends StatelessWidget {
  final String pin;

  const _PinStrengthBar({required this.pin});

  @override
  Widget build(BuildContext context) {
    final score = _strength(pin);
    final scheme = Theme.of(context).colorScheme;

    Color color;
    String label;
    if (score == 0) {
      return const SizedBox.shrink();
    } else if (score <= 1) {
      color = scheme.error;
      label = '弱';
    } else if (score <= 2) {
      color = scheme.tertiary;
      label = '中';
    } else {
      color = scheme.primary;
      label = '强';
    }

    return Column(
      children: [
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: score / 3,
            backgroundColor: scheme.surfaceContainerHighest,
            color: color,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  int _strength(String pin) {
    if (pin.length < 6) return 0;
    var score = 0;
    if (pin.length >= 8) score++;
    if (pin.contains(RegExp(r'[A-Z]'))) score++;
    if (pin.contains(RegExp(r'[^a-zA-Z0-9]'))) score++;
    return score;
  }
}

// ── Word chip ───────────────────────────────────────────────────────

class _WordChip extends StatelessWidget {
  final int index;
  final String word;
  final Color primary;

  const _WordChip({
    required this.index,
    required this.word,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
          ),
          child: Text('$index',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Text(word,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 2,
              )),
        ),
      ],
    );
  }
}
