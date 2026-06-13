import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

/// Immediately clear credit.yourtj.de localStorage + cookies.
Future<void> clearCreditStorage() async {
  const clearJs = '''
(function() {
  try {
    localStorage.removeItem('yourtj_credit_wallet');
    localStorage.removeItem('yourtj_terms_accepted_v1');
    localStorage.removeItem('studentId');
  } catch(e) {}
})();
''';

  try {
    // 1) Clear cookies immediately.
    final cookieManager = CookieManager.instance();
    await cookieManager.deleteCookies(url: WebUri('https://credit.yourtj.de'));

    // 2) Clear localStorage via headless WebView.
    final headless = HeadlessInAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
      ),
      initialUrlRequest: URLRequest(url: WebUri('https://credit.yourtj.de')),
    );
    await headless.run();
    await Future.delayed(const Duration(milliseconds: 500));
    final ctrl = headless.webViewController;
    if (ctrl != null) {
      await ctrl.evaluateJavascript(source: clearJs);
    }
    await headless.dispose();
  } catch (_) {
    // Best-effort; WebView storage is also cleared on next visible load.
  }
}

/// Opens [credit.yourtj.de] in an in-app WebView with reliable login state.
///
/// Strategy: Uses [initialUserScripts] with [UserScriptInjectionTime.AT_DOCUMENT_START]
/// to inject wallet credentials into localStorage BEFORE the React app initializes.
/// The credentials are read asynchronously in initState, and the WebView is only
/// created after they're available (via a loading gate).
///
/// Register mode: monitors localStorage and captures new credentials.
class CreditWebViewPage extends StatefulWidget {
  const CreditWebViewPage({
    super.key,
    this.targetPath = '',
    this.registerMode = false,
  });

  final String targetPath;
  final bool registerMode;

  @override
  State<CreditWebViewPage> createState() => _CreditWebViewPageState();
}

class _CreditWebViewPageState extends State<CreditWebViewPage> {
  InAppWebViewController? _controller;
  var _isLoading = true;
  var _progress = 0.0;
  var _hasError = false;

  // Credentials loaded BEFORE WebView creation.
  String? _mnemonic;
  String? _hash;
  String? _secret;
  var _credsReady = false;

  String get _targetUrl {
    final base = 'https://credit.yourtj.de';
    // Marketplace is at /dashboard/marketplace (nested under dashboard route).
    // Direct /marketpage hits the catch-all /* which redirects to / (login page).
    if (widget.targetPath == 'marketplace-tasks') return '$base/#/dashboard/marketplace';
    if (widget.targetPath == 'marketplace-products') return '$base/#/dashboard/marketplace';
    if (widget.targetPath.isNotEmpty) return '$base/#/${widget.targetPath}';
    return base;
  }

  // ── Secure storage keys ────────────────────────────────────────
  static const _mnemonicKey = 'de.yourtj.course.wallet.mnemonic';
  static const _hashKey = 'de.yourtj.course.wallet.userHash';
  static const _secretKey = 'de.yourtj.course.wallet.userSecret';
  static const _termsKey = 'de.yourtj.course.termsAccepted';

  /// UserScript: inject wallet credentials into localStorage at document start,
  /// BEFORE the React app's useState(loadWallet()) runs.
  UnmodifiableListView<UserScript>? get _injectScript {
    final m = _mnemonic;
    final h = _hash;
    final s = _secret;
    if (m == null || m.isEmpty || h == null || h.isEmpty || s == null || s.isEmpty) return null;
    return UnmodifiableListView([
      UserScript(
        source: '''
(function() {
  try {
    localStorage.setItem('yourtj_credit_wallet', JSON.stringify({
      mnemonic: ${jsonEncode(m)},
      userHash: ${jsonEncode(h)},
      userSecret: ${jsonEncode(s)},
      createdAt: Date.now()
    }));
    localStorage.setItem('yourtj_terms_accepted_v1', '1');
  } catch(e) {}
})();
''',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: true,
      ),
    ]);
  }

  /// JS: clear all credit site localStorage keys.
  static const _kClearStorageJs = '''
(function() {
  try {
    localStorage.removeItem('yourtj_credit_wallet');
    localStorage.removeItem('yourtj_terms_accepted_v1');
    localStorage.removeItem('studentId');
  } catch(e) {}
})();
''';

  /// JS: switch to correct marketplace tab.
  String _tabSwitchJs() {
    final parts = widget.targetPath.split('-');
    if (parts.length < 2 || parts[0] != 'marketplace') return '';
    final tab = parts[1];
    return '''
(function() {
  var TAB = '$tab';
  var start = Date.now();
  function click() {
    var btns = document.querySelectorAll('button');
    for (var i = 0; i < btns.length; i++) {
      var txt = btns[i].textContent.trim().toLowerCase();
      if (txt.indexOf(TAB === 'tasks' ? '悬赏' : '商品') >= 0 || txt.indexOf(TAB) >= 0) {
        btns[i].click(); return;
      }
    }
    if (Date.now() - start < 8000) setTimeout(click, 300);
  }
  setTimeout(click, 500);
})();
''';
  }

  /// JS: monitor localStorage for new wallet credentials (register mode).
  static String _walletMonitorJs(String handlerName) => '''
(function() {
  var KEY = 'yourtj_credit_wallet';
  function checkWallet() {
    var raw = localStorage.getItem(KEY);
    if (raw) {
      try {
        var data = JSON.parse(raw);
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('$handlerName', JSON.stringify({
            mnemonic: data.mnemonic,
            userHash: data.userHash,
            userSecret: data.userSecret
          }));
        }
      } catch(e) {}
    }
  }
  checkWallet();
  setInterval(checkWallet, 2000);
})();
''';

  @override
  void initState() {
    super.initState();
    if (!widget.registerMode) {
      _loadCredentials().then((_) {
        if (mounted) setState(() => _credsReady = true);
      });
    } else {
      _credsReady = true;
    }
  }

  Future<void> _loadCredentials() async {
    const storage = FlutterSecureStorage();
    _hash = await storage.read(key: _hashKey);
    _secret = await storage.read(key: _secretKey);
    _mnemonic = await storage.read(key: _mnemonicKey);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onWalletReceived(dynamic args) async {
    if (!widget.registerMode) return;
    if (args.isEmpty) return;
    try {
      final raw = args[0];
      if (raw is! String) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final mnemonic = data['mnemonic'] as String?;
      final userHash = data['userHash'] as String?;
      final userSecret = data['userSecret'] as String?;
      if (mnemonic == null || userHash == null || userSecret == null) return;

      const storage = FlutterSecureStorage();
      await storage.write(key: _mnemonicKey, value: mnemonic);
      await storage.write(key: _hashKey, value: userHash);
      await storage.write(key: _secretKey, value: userSecret);
      await storage.write(key: _termsKey, value: '1');

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_credsReady) {
      return PopScope(
        canPop: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('YourTJ Credit')),
          body: Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          ),
        ),
      );
    }

    final injectScript = _injectScript;
    final hasWallet = injectScript != null;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('YourTJ Credit'),
          actions: [
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        body: _hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 48,
                        color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('加载失败'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() => _hasError = false);
                        _controller?.loadUrl(
                          urlRequest: URLRequest(url: WebUri(_targetUrl)),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isLoading)
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  Expanded(
                    child: InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        sharedCookiesEnabled: true,
                        cacheEnabled: true,
                        transparentBackground: false,
                        blockNetworkImage: false,
                        mediaPlaybackRequiresUserGesture: false,
                        allowsInlineMediaPlayback: true,
                        thirdPartyCookiesEnabled: true,
                        useShouldOverrideUrlLoading: false,
                        useOnDownloadStart: false,
                      ),
                      initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
                      // AT_DOCUMENT_START: injects localStorage BEFORE React
                      // initializes, so useState(loadWallet()) finds credentials.
                      initialUserScripts: hasWallet && !widget.registerMode
                          ? injectScript
                          : null,
                      onWebViewCreated: (ctrl) {
                        _controller = ctrl;
                        ctrl.addJavaScriptHandler(
                          handlerName: 'WalletChannel',
                          callback: _onWalletReceived,
                        );
                      },
                      onLoadStart: (ctrl, url) {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                      },
                      onPermissionRequest: (ctrl, request) async {
                        final hasNonCamera = request.resources.any(
                          (r) => r != PermissionResourceType.CAMERA,
                        );
                        if (hasNonCamera) {
                          return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.DENY,
                          );
                        }
                        final needsCamera = request.resources.any(
                          (r) => r == PermissionResourceType.CAMERA,
                        );
                        if (needsCamera) {
                          final status = await Permission.camera.request();
                          if (!status.isGranted) {
                            return PermissionResponse(
                              resources: [PermissionResourceType.CAMERA],
                              action: PermissionResponseAction.DENY,
                            );
                          }
                        }
                        return PermissionResponse(
                          resources: [PermissionResourceType.CAMERA],
                          action: PermissionResponseAction.GRANT,
                        );
                      },
                      onReceivedError: (ctrl, request, error) {
                        debugPrint('[CreditWebView] error: ${error.description}');
                        setState(() => _hasError = true);
                      },
                      onProgressChanged: (ctrl, progress) {
                        setState(() => _progress = progress / 100);
                      },
                      onLoadStop: (ctrl, url) async {
                        setState(() => _isLoading = false);

                        if (widget.registerMode) {
                          await ctrl.evaluateJavascript(
                            source: _walletMonitorJs('WalletChannel'),
                          );
                          return;
                        }

                        // Browsing mode: clearance for pages without wallet.
                        if (!hasWallet) {
                          await ctrl.evaluateJavascript(source: _kClearStorageJs);
                        }

                        // Tab switch for marketplace.
                        if (widget.targetPath.startsWith('marketplace-')) {
                          await ctrl.evaluateJavascript(source: _tabSwitchJs());
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
