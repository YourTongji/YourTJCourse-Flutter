import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'log_writer.dart';

/// 日志文件管理工具
class LoggerUtils {
  LoggerUtils._();

  /// 过期天数
  static const int _expireDays = 14;

  /// 获取日志文件
  static Future<File> getLogFile() => LogWriter.getLogFile();

  /// 获取人类可读的设备和应用信息文本（用于复制）
  static Future<String> getDeviceInfoText() async {
    final buf = StringBuffer();
    try {
      final pkg = await PackageInfo.fromPlatform();
      buf.writeln('应用: ${pkg.appName}');
      buf.writeln('版本: ${pkg.version} (${pkg.buildNumber})');
      buf.writeln('包名: ${pkg.packageName}');
    } catch (_) {}
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        buf.writeln('平台: Android ${info.version.release} (SDK ${info.version.sdkInt})');
        buf.writeln('设备: ${info.brand} ${info.model}');
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        buf.writeln('平台: iOS ${info.systemVersion}');
        buf.writeln('设备: ${info.utsname.machine}');
      }
    } catch (_) {}
    return buf.toString().trimRight();
  }

  /// 读取并解析 JSONL，逆序返回（最新在前）
  static Future<List<Map<String, dynamic>>> readLogEntries() async {
    final file = await getLogFile();
    if (!file.existsSync()) return [];
    final content = await LogWriter.readContentSafely(file);
    if (content.trim().isEmpty) return [];
    final lines = content.trim().split('\n');
    final entries = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        json['level'] ??= 'error';
        json['type'] ??= 'general';
        if (json['message'] == null) {
          final customParams = json['customParameters'] as Map<String, dynamic>?;
          json['message'] = customParams?['message']?.toString() ?? json['error']?.toString();
          json['tag'] ??= customParams?['tag']?.toString();
        }
        entries.add(json);
      } catch (_) {}
    }
    return entries.reversed.toList();
  }

  /// 读取原始文本
  static Future<String> readLogContent() async {
    final file = await getLogFile();
    if (!file.existsSync()) return '';
    return LogWriter.readContentSafely(file);
  }

  /// 清理过期日志
  static Future<void> cleanExpiredLogs() async {
    final file = await getLogFile();
    if (!file.existsSync()) return;
    final content = await LogWriter.readContentSafely(file);
    if (content.trim().isEmpty) return;
    final lines = content.trim().split('\n');
    final now = DateTime.now();
    final retained = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final timestamp = json['timestamp'] as String?;
        if (timestamp != null) {
          final time = DateTime.tryParse(timestamp);
          if (time != null && now.difference(time).inDays < _expireDays) {
            retained.add(line);
          }
        }
      } catch (_) {}
    }
    await file.writeAsString('${retained.join('\n')}\n');
  }

  /// 清空日志
  static Future<void> clearLogs() async {
    final file = await getLogFile();
    if (file.existsSync()) await file.writeAsString('');
  }
}
