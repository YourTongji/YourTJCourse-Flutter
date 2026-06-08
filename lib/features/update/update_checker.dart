import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';

/// Result of an auto-update check.
class UpdateInfo {
  const UpdateInfo({
    required this.tagName,
    required this.releaseName,
    required this.downloadUrl,
    required this.assetName,
  });

  final String tagName;
  final String releaseName;
  final String downloadUrl;
  final String assetName;
}

/// Version info parsed from a GitHub release.
class _ReleaseInfo {
  const _ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.targetCommitish,
    required this.apkAssets,
  });

  factory _ReleaseInfo.fromJson(Object? json) {
    final map = json is Map ? Map<String, Object?>.from(json) : const {};
    final assetsRaw = map['assets'];
    final assets = assetsRaw is List
        ? assetsRaw
            .map(_ReleaseAsset.fromJson)
            .where((asset) => asset.name.endsWith('.apk'))
            .toList(growable: false)
        : const <_ReleaseAsset>[];
    return _ReleaseInfo(
      tagName: '${map['tag_name'] ?? ''}',
      name: '${map['name'] ?? 'YourTJ Course'}',
      targetCommitish: '${map['target_commitish'] ?? ''}',
      apkAssets: assets,
    );
  }

  final String tagName;
  final String name;
  final String targetCommitish;
  final List<_ReleaseAsset> apkAssets;

  _ReleaseAsset? findBestAsset(List<String> supportedAbis) {
    final preferredAbis = supportedAbis.isEmpty
        ? const ['arm64-v8a', 'armeabi-v7a', 'x86_64']
        : supportedAbis;
    for (final abi in preferredAbis) {
      for (final asset in apkAssets) {
        if (asset.abi == abi) return asset;
      }
    }
    if (apkAssets.length == 1) return apkAssets.single;
    return null;
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({required this.name, required this.browserDownloadUrl});

  factory _ReleaseAsset.fromJson(Object? json) {
    final map = json is Map ? Map<String, Object?>.from(json) : const {};
    return _ReleaseAsset(
      name: '${map['name'] ?? ''}',
      browserDownloadUrl: '${map['browser_download_url'] ?? ''}',
    );
  }

  final String name;
  final String browserDownloadUrl;

  String? get abi {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('arm64-v8a')) return 'arm64-v8a';
    if (lowerName.contains('armeabi-v7a')) return 'armeabi-v7a';
    if (lowerName.contains('x86_64')) return 'x86_64';
    if (lowerName.contains('x86')) return 'x86';
    return null;
  }
}

/// Provider that auto-checks for app updates.
/// Returns null if already on the latest build or no matching APK found.
final autoUpdateProvider = FutureProvider.autoDispose<UpdateInfo?>((ref) {
  return AutoUpdateChecker.instance.check();
});

class AutoUpdateChecker {
  AutoUpdateChecker._();

  static final instance = AutoUpdateChecker._();

  static const _repo = 'YourTongji/YourTJCourse-Flutter';
  static const _apiBase = 'https://api.github.com/repos/$_repo';
  static const _defaultAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
  static const _channel = 'dev-latest';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/vnd.github+json'},
    ),
  );

  static const _platform = MethodChannel('de.yourtj.course.flutter/updater');

  /// Check for updates silently. Returns null when already up-to-date,
  /// no matching APK is found, or the check fails (failures are swallowed).
  Future<UpdateInfo?> check() async {
    try {
      final currentSha = AppConfig.fromEnv().buildSha;
      if (currentSha.isEmpty) return null;

      final supportedAbis = await _readSupportedAbis();
      final response = await _dio.get<Object?>(
        '$_apiBase/releases/tags/$_channel',
      );
      final release = _ReleaseInfo.fromJson(response.data);

      if (release.targetCommitish == currentSha) return null;

      final asset = release.findBestAsset(supportedAbis);
      if (asset == null) return null;

      return UpdateInfo(
        tagName: release.tagName,
        releaseName: release.name,
        downloadUrl: asset.browserDownloadUrl,
        assetName: asset.name,
      );
    } catch (_) {
      // Silently swallow all errors — auto-check failures must not
      // interrupt the user experience.
      return null;
    }
  }

  Future<List<String>> _readSupportedAbis() async {
    if (!Platform.isAndroid) return _defaultAbis;
    try {
      final result = await _platform.invokeListMethod<String>(
        'getSupportedAbis',
      );
      return result ?? _defaultAbis;
    } on PlatformException {
      return _defaultAbis;
    }
  }
}

/// Mirror list for GitHub release downloads.
const kDownloadMirrors = [
  'https://gh-proxy.com/',
  'https://gh.llkk.cc/',
  'https://gh-proxy.net/',
  'https://hub.gitmirror.com/',
];
