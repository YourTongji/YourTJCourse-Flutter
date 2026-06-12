import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/log_writer.dart';
import '../../services/logger_utils.dart';

enum _LogFilter { all, error, request, lifecycle }

class AppLogsPage extends StatefulWidget {
  const AppLogsPage({super.key});
  @override
  State<AppLogsPage> createState() => _AppLogsPageState();
}

class _AppLogsPageState extends State<AppLogsPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  _LogFilter _filter = _LogFilter.all;

  @override
  void initState() { super.initState(); _loadLogs(); }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case _LogFilter.all: return _entries;
      case _LogFilter.error: return _entries.where((e) => e['level'] == 'error').toList();
      case _LogFilter.request: return _entries.where((e) => e['type'] == 'request').toList();
      case _LogFilter.lifecycle: return _entries.where((e) => e['type'] == 'lifecycle').toList();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final entries = await LoggerUtils.readLogEntries();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _copyDeviceInfo() async {
    final text = await LoggerUtils.getDeviceInfoText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast('已复制设备信息');
  }

  Future<void> _shareLog() async {
    final file = await LogWriter.getLogFile();
    if (!file.existsSync()) { _toast('暂无日志'); return; }
    final dir = await getApplicationDocumentsDirectory();
    final shareFile = File('${dir.path}/app_log_share.jsonl');
    await file.copy(shareFile.path);
    await SharePlus.instance.share(ShareParams(files: [XFile(shareFile.path)], text: '应用日志'));
  }

  Future<void> _clearLogs() async {
    final ok = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('清除日志'), content: const Text('确定清除所有应用日志？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) { await LoggerUtils.clearLogs(); await _loadLogs(); _toast('日志已清除'); }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  (IconData, Color) _getIcon(Map<String, dynamic> e) {
    final level = (e['level'] ?? 'error').toString();
    final type = (e['type'] ?? 'general').toString();
    if (type == 'request') return (Icons.http, Colors.blue);
    if (type == 'lifecycle') return (Icons.timeline, Colors.teal);
    return switch (level) {
      'error' => (Icons.error_outline, Colors.red),
      'warning' => (Icons.warning_amber_outlined, Colors.orange),
      _ => (Icons.info_outline, Colors.grey),
    };
  }

  String _getTitle(Map<String, dynamic> e) {
    final type = (e['type'] ?? '').toString();
    if (type == 'request') {
      final method = (e['method'] ?? '').toString();
      final url = (e['url'] ?? '').toString();
      final path = Uri.tryParse(url)?.path ?? url;
      return '$method $path';
    }
    if (type == 'lifecycle') return e['message']?.toString() ?? '生命周期事件';
    final msg = e['message']?.toString() ?? e['error']?.toString() ?? '';
    final tag = e['tag']?.toString();
    return tag != null ? '[$tag] $msg' : msg;
  }

  String _getSubtitle(Map<String, dynamic> e) {
    final type = (e['type'] ?? '').toString();
    if (type == 'request') {
      final sc = e['statusCode']; final dur = e['duration'];
      return [if (sc != null) '$sc', if (dur != null) '${dur}ms'].join(' · ');
    }
    if (type == 'lifecycle') return '';
    return e['message']?.toString() ?? '';
  }

  String _fmtTs(String? ts) {
    final t = DateTime.tryParse(ts ?? '');
    if (t == null) return ts ?? '';
    final l = t.toLocal();
    return '${l.month}-${l.day.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 2),
        SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> e) {
    final ts = e['timestamp']?.toString() ?? '';
    final method = e['method']?.toString();
    final url = e['url']?.toString();
    final statusCode = e['statusCode']?.toString();
    final duration = e['duration'];
    final level = (e['level'] ?? '').toString();
    final message = e['message']?.toString() ?? '';
    final error = e['error']?.toString();
    final errorType = e['errorType']?.toString();
    final stack = e['stackTrace']?.toString();
    final tag = e['tag']?.toString();
    final type = (e['type'] ?? '').toString();
    final event = e['event']?.toString();

    String detail;
    if (type == 'request') {
      detail = '时间: $ts\n方法: $method\nURL: $url\n状态码: ${statusCode ?? '-'}\n耗时: ${duration != null ? '${duration}ms' : '-'}\n级别: $level';
    } else {
      detail = '时间: $ts\n级别: $level\n消息: $message'
        '${tag != null ? '\n标签: $tag' : ''}'
        '${event != null ? '\n事件: $event' : ''}'
        '${error != null && error != message ? '\n错误: $error' : ''}'
        '${errorType != null ? '\n类型: $errorType' : ''}'
        '${stack != null ? '\n堆栈:\n$stack' : ''}';
    }

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(_getTitle(e), style: Theme.of(context).textTheme.titleMedium)),
        IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () {
          Clipboard.setData(ClipboardData(text: detail));
          _toast('已复制');
        }),
      ]),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (type == 'request') ...[
            _detailField('时间', ts),
            if (method != null) _detailField('方法', method),
            if (url != null) _detailField('URL', url),
            _detailField('状态码', statusCode ?? '-'),
            _detailField('耗时', duration != null ? '${duration}ms' : '-'),
            _detailField('级别', level),
          ] else ...[
            _detailField('时间', ts),
            _detailField('级别', level),
            _detailField('消息', message),
            if (tag != null) _detailField('标签', tag),
            if (event != null) _detailField('事件', event),
            if (error != null && error != message) _detailField('错误', error),
            if (errorType != null) _detailField('类型', errorType),
            if (stack != null) ...[const SizedBox(height: 12), _detailField('堆栈', stack)],
          ],
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用日志'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(onSelected: (v) {
            switch (v) {
              case 'deviceInfo': _copyDeviceInfo();
              case 'share': _shareLog();
              case 'clear': _clearLogs();
            }
          }, itemBuilder: (_) => [
            const PopupMenuItem(value: 'deviceInfo', child: ListTile(leading: Icon(Icons.smartphone), title: Text('复制设备信息'), dense: true, contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('分享日志'), dense: true, contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('清除日志'), dense: true, contentPadding: EdgeInsets.zero)),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.article_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('暂无日志', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline)),
                ]))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      _fc('全部', _LogFilter.all), const SizedBox(width: 8),
                      _fc('错误', _LogFilter.error), const SizedBox(width: 8),
                      _fc('请求', _LogFilter.request), const SizedBox(width: 8),
                      _fc('生命周期', _LogFilter.lifecycle),
                    ]),
                  ),
                  Expanded(child: _filtered.isEmpty
                      ? Center(child: Text('无匹配日志', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.outline)))
                      : RefreshIndicator(onRefresh: _loadLogs, child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final e = _filtered[i];
                            final (icon, color) = _getIcon(e);
                            return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), clipBehavior: Clip.antiAlias, child: ListTile(
                              leading: Icon(icon, color: color),
                              title: Text(_getTitle(e), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (_getSubtitle(e).isNotEmpty) Text(_getSubtitle(e), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text(_fmtTs(e['timestamp']?.toString()), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                              ]),
                              onTap: () => _showDetail(e),
                            ));
                          },
                        ))),
                ]),
    );
  }

  Widget _fc(String label, _LogFilter f) {
    final sel = _filter == f;
    return FilterChip(label: Text(label), selected: sel, showCheckmark: false, onSelected: (_) => setState(() => _filter = f));
  }
}
