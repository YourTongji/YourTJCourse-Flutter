// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_checker.dart';

/// Wraps the app shell and shows an update-available dialog once when
/// the [autoUpdateProvider] resolves to a newer release.
class AutoUpdateGate extends ConsumerStatefulWidget {
  const AutoUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoUpdateGate> createState() => _AutoUpdateGateState();
}

class _AutoUpdateGateState extends ConsumerState<AutoUpdateGate> {
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(autoUpdateProvider, (_, next) {
      if (_shown) return;
      if (!next.hasValue) return;
      final update = next.value;
      if (update == null) return;
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showUpdateDialog(context, update);
      });
    });
    return widget.child;
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(context);
        return AlertDialog(
          icon: ClipOval(child: Image.asset('assets/images/app_logo.png', height: 52)),
          title: const Text('发现新版本', textAlign: TextAlign.center),
          content: Text(
            '新版本 ${update.tagName} 已发布，是否下载更新？',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('稍后'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _startDownload(context, update);
              },
              icon: const Icon(Icons.download_for_offline_outlined, size: 18),
              label: const Text('下载更新'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDownload(BuildContext context, UpdateInfo update) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始下载更新...')),
    );

    try {
      final directory = await getTemporaryDirectory();
      final safeName = update.assetName.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );
      final file = File('${directory.path}/$safeName');
      const platform = MethodChannel('de.yourtj.course.flutter/updater');

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      DioException? lastError;
      final candidates = _downloadCandidates(update.downloadUrl);

      for (final url in candidates) {
        try {
          await dio.download(url, file.path, deleteOnError: true);
          if (!mounted) return;
          await platform.invokeMethod<void>('installApk', {'path': file.path});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('下载完成，请按系统提示安装。')),
          );
          return;
        } on DioException catch (e) {
          lastError = e;
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('下载失败，使用备用地址重试...'),
              duration: const Duration(seconds: 1),
            ),
          );
          continue;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败: ${lastError?.message ?? "未知错误"}')),
      );
    } finally {
      // no-op cleanup
    }
  }

  List<String> _downloadCandidates(String url) {
    const base = 'https://github.com/YourTongji/YourTJCourse-Flutter';
    final normalized = url.startsWith(base) ? url : url.trim();
    return [
      for (final mirror in kDownloadMirrors) '$mirror$normalized',
      normalized,
    ];
  }
}
