import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('更多')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Image.asset('assets/images/app_logo.png', width: 56),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YourTJ Course',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text('Flutter Android 预发测试客户端'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('公告'),
            subtitle: const Text('查看当前运行时公告'),
            onTap: () => _showAnnouncements(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('反馈与建议'),
            subtitle: const Text('打开 GitHub Issues'),
            onTap: () => _openLink(
              context,
              'https://github.com/YourTongji/YourTJCourse-Flutter/issues',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('后端仓库'),
            subtitle: const Text('YourTJCourse-Serverless'),
            onTap: () => _openLink(
              context,
              'https://github.com/YourTongji/YourTJCourse-Serverless',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.phone_android_outlined),
            title: const Text('客户端仓库'),
            subtitle: const Text('YourTJCourse-Flutter'),
            onTap: () => _openLink(
              context,
              'https://github.com/YourTongji/YourTJCourse-Flutter',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('用户协议 (EULA)'),
            subtitle: const Text('查看服务说明与免责声明'),
            onTap: () => _showTextSheet(context, '用户协议 (EULA)', _eulaText),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于选课社区'),
            subtitle: const Text('社区介绍、机制与致谢'),
            onTap: () => _showAboutCommunity(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('常见问题'),
            subtitle: const Text('点评、社区管理与联系方式'),
            onTap: () => _showFaq(context),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            subtitle: const Text('查看数据收集与安全说明'),
            onTap: () => _showPrivacy(context),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('社区规范'),
            subtitle: const Text('评价支持隐藏与举报，请保持真实、克制和可验证'),
            onTap: () =>
                _showTextSheet(context, '社区规范', _communityGuidelinesText),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('安全与合规'),
            subtitle: const Text('Release 默认 HTTPS，评价提供举报与隐藏入口'),
            onTap: () => _showTextSheet(context, '安全与合规', _safetyText),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 YourTJ Course'),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开浏览器，已复制链接')));
  }

  void _showAnnouncements(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder(
          future: ref.read(settingsRepositoryProvider).getRuntimeState(),
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final announcements = state?.announcements ?? const [];
            if (announcements.isEmpty) {
              return const SizedBox(
                height: 180,
                child: Center(child: Text('暂无公告')),
              );
            }
            return SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemBuilder: (context, index) {
                  final item = announcements[index];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.content),
                  );
                },
                separatorBuilder: (_, _) => const Divider(),
                itemCount: announcements.length,
              ),
            );
          },
        );
      },
    );
  }

  void _showTextSheet(BuildContext context, String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(content),
            ],
          ),
        );
      },
    );
  }

  void _showAboutCommunity(BuildContext context) {
    _showRichTextSheet(context, '关于选课社区', [
      _SheetParagraph('简介', _aboutIntro),
      _SheetParagraph('匿名身份', _aboutAnonymous),
      _SheetParagraph('点评管理', _aboutModeration),
      const _SheetParagraph('联系方式', '您目前可以通过邮件联系我们。'),
      const _SheetLink('support@yourtj.de', 'mailto:support@yourtj.de'),
      _SheetParagraph('致谢', 'YOURTJ选课社区基于 SJTU选课社区 源代码。'),
      _SheetLink(
        'YOURTJ选课社区',
        'https://github.com/WALKERKILLER/TongjiCourses-Serverless',
      ),
      _SheetLink('SJTU选课社区', 'https://github.com/SJTU-jCourse/jcourse'),
      _SheetParagraph('', 'YOURTJ选课社区人机验证基于 BangCaptcha 源代码。'),
      _SheetLink(
        'YOURTJ选课社区人机验证',
        'https://github.com/WALKERKILLER/TongjiCaptcha',
      ),
      _SheetLink('BangCaptcha', 'https://github.com/YuiNijika/BangCaptcha'),
      _SheetParagraph('', '排课模拟器及高级检索基于 TONGJI-COURSE-SCHEDULER 源代码。'),
      _SheetLink(
        'TONGJI-COURSE-SCHEDULER',
        'https://github.com/XiaLing233/tongji-course-scheduler',
      ),
    ]);
  }

  void _showFaq(BuildContext context) {
    _showRichTextSheet(context, '常见问题', const [
      _SheetParagraph('我该点评哪些课程？写什么？', _faqReviewTarget),
      _SheetParagraph('选课社区是用来找到“水课”的吗？', _faqPurpose),
      _SheetParagraph('我喜欢看 1-5 星评分的数据，不喜欢看字。', _faqRating),
      _SheetParagraph('选课社区谁开发和部署的？', '同济大学在校（或曾经在校）生。'),
      _SheetParagraph('选课社区由谁来管理？', '同济大学在校（或曾经在校）生。'),
      _SheetParagraph('我会因为在这里发表点评而被约谈吗？', '不会，因为选课社区采用不记名制。'),
      _SheetParagraph('网站上的内容是否受管理？', _faqModeration),
      _SheetParagraph('如何界定社区内容的版权问题？', _faqCopyright),
      _SheetParagraph('如何联系你们？', '请通过邮件向社区提出意见和建议。'),
      _SheetLink('support@yourtj.de', 'mailto:support@yourtj.de'),
      _SheetParagraph('我是课程老师……', _faqTeacher),
      _SheetLink('support@yourtj.de', 'mailto:support@yourtj.de'),
    ]);
  }

  void _showPrivacy(BuildContext context) {
    _showRichTextSheet(context, '隐私政策', const [
      _SheetParagraph('', _privacyIntro),
      _SheetParagraph('信息收集', _privacyCollection),
      _SheetParagraph('第三方代码', _privacyThirdParty),
      _SheetParagraph('数据传输与存储', _privacyTransport),
      _SheetParagraph('数据安全', _privacySecurity),
      _SheetParagraph('数据保留与删除', _privacyRetention),
      _SheetParagraph('儿童隐私', _privacyChildren),
      _SheetParagraph('政策变更', _privacyChanges),
      _SheetParagraph('联系我们', '您可以通过以下入口联系我们。'),
      _SheetLink(
        'GitHub Issues',
        'https://github.com/YourTongji/YourTJCourse-Flutter/issues',
      ),
      _SheetLink('项目仓库', 'https://github.com/YourTongji/YourTJCourse-Flutter'),
    ]);
  }

  void _showRichTextSheet(
    BuildContext context,
    String title,
    List<_SheetContent> content,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final item in content) item.build(context, _openLink),
            ],
          ),
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'YourTJ Course',
      applicationVersion: '0.0.1',
      applicationIcon: Image.asset('assets/images/app_logo.png', width: 56),
      children: [
        const Text('YourTJ选课社区安卓客户端'),
        const SizedBox(height: 12),
        _ReleaseUpdateChecker(openLink: _openLink),
      ],
    );
  }
}

enum _ReleaseChannel {
  stable('正式版', 'latest'),
  testing('测试版', 'dev-latest');

  const _ReleaseChannel(this.label, this.tag);

  final String label;
  final String tag;
}

class _ReleaseUpdateChecker extends StatefulWidget {
  const _ReleaseUpdateChecker({required this.openLink});

  final Future<void> Function(BuildContext, String) openLink;

  @override
  State<_ReleaseUpdateChecker> createState() => _ReleaseUpdateCheckerState();
}

class _ReleaseUpdateCheckerState extends State<_ReleaseUpdateChecker> {
  static const _repo = 'YourTongji/YourTJCourse-Flutter';
  static const _githubBase = 'https://github.com/$_repo';
  static const _apiBase = 'https://api.github.com/repos/$_repo';
  static const _platform = MethodChannel('de.yourtj.course.flutter/updater');
  static const _downloadMirrors = [
    'https://gh-proxy.com/',
    'https://gh.llkk.cc/',
    'https://gh-proxy.net/',
    'https://hub.gitmirror.com/',
  ];

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {'Accept': 'application/vnd.github+json'},
    ),
  );

  _ReleaseChannel _channel = _ReleaseChannel.testing;
  _ReleaseInfo? _release;
  _ReleaseAsset? _recommendedAsset;
  var _currentRelease = false;
  var _checking = false;
  var _downloading = false;
  var _downloadProgress = 0.0;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final release = _release;
    final asset = _recommendedAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_ReleaseChannel>(
          segments: const [
            ButtonSegment(
              value: _ReleaseChannel.stable,
              label: Text('正式版'),
              icon: Icon(Icons.verified_outlined),
            ),
            ButtonSegment(
              value: _ReleaseChannel.testing,
              label: Text('测试版'),
              icon: Icon(Icons.science_outlined),
            ),
          ],
          selected: {_channel},
          onSelectionChanged: _checking || _downloading
              ? null
              : (value) => setState(() {
                  _channel = value.single;
                  _release = null;
                  _message = null;
                }),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _checking || _downloading ? null : _checkRelease,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_alt_outlined),
          label: Text(_checking ? '检查中...' : '检查更新'),
        ),
        if (_downloading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: _downloadProgress),
          const SizedBox(height: 6),
          Text(
            '正在下载 ${(_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (release != null) ...[
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${release.name} · ${release.tagName}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (asset == null)
                    Text(
                      _currentRelease ? '当前已经是最新版本' : '未找到适配当前设备的 APK。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _currentRelease
                            ? scheme.onSurfaceVariant
                            : scheme.error,
                      ),
                    )
                  else ...[
                    Text('将下载：${asset.name}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _downloading ? null : () => _download(asset),
                      icon: const Icon(Icons.download_for_offline_outlined),
                      label: const Text('确认更新'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _checkRelease() async {
    setState(() {
      _checking = true;
      _message = null;
      _release = null;
      _recommendedAsset = null;
      _currentRelease = false;
    });
    try {
      final supportedAbis = await _readSupportedAbis();
      final response = await _dio.get<Object?>(
        '$_apiBase/releases/tags/${_channel.tag}',
      );
      final release = _ReleaseInfo.fromJson(response.data);
      final currentBuildSha = AppConfig.fromEnv().buildSha;
      final isCurrentBuild =
          currentBuildSha.isNotEmpty &&
          release.targetCommitish.isNotEmpty &&
          release.targetCommitish == currentBuildSha;
      final recommendedAsset = release.findBestAsset(supportedAbis);
      if (!mounted) return;
      setState(() {
        _release = release;
        _currentRelease = isCurrentBuild;
        _recommendedAsset = isCurrentBuild ? null : recommendedAsset;
        _message = isCurrentBuild
            ? '当前已经是最新版本'
            : release.apkAssets.isEmpty
            ? '${_channel.label}没有可下载的 APK'
            : recommendedAsset == null
            ? '已找到${_channel.label}，但没有匹配当前 CPU 架构的 APK'
            : '已找到${_channel.label}，已自动匹配安装包。';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.response?.statusCode == 404
            ? '暂未发布${_channel.label}安装包'
            : '检查失败，请稍后重试';
      });
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<List<String>> _readSupportedAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      final result = await _platform.invokeListMethod<String>(
        'getSupportedAbis',
      );
      return result ?? const [];
    } on PlatformException {
      return const [];
    }
  }

  Future<void> _download(_ReleaseAsset asset) async {
    if (!Platform.isAndroid) {
      await widget.openLink(context, asset.browserDownloadUrl);
      return;
    }
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _message = '正在准备下载...';
    });

    try {
      final file = await _downloadTargetFile(asset.name);
      DioException? lastError;
      for (final url in _downloadCandidates(asset.browserDownloadUrl)) {
        try {
          await _dio.download(
            url,
            file.path,
            deleteOnError: true,
            onReceiveProgress: (received, total) {
              if (!mounted || total <= 0) return;
              setState(() => _downloadProgress = received / total);
            },
          );
          await _installApk(file.path);
          if (!mounted) return;
          setState(() {
            _message = '下载完成，请按系统提示安装。';
            _downloadProgress = 1;
          });
          return;
        } on DioException catch (error) {
          lastError = error;
          continue;
        } on PlatformException catch (error) {
          if (!mounted) return;
          setState(() => _message = error.message ?? '无法启动系统安装器');
          return;
        }
      }

      if (!mounted) return;
      final officialUrl = asset.browserDownloadUrl;
      await Clipboard.setData(ClipboardData(text: officialUrl));
      if (!mounted) return;
      setState(() {
        _message = lastError?.message == null
            ? '下载失败，已复制官方下载地址'
            : '下载失败，已复制官方下载地址';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下载失败，已复制官方下载地址')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<File> _downloadTargetFile(String assetName) async {
    final directory = await getTemporaryDirectory();
    final safeName = assetName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${directory.path}/$safeName');
  }

  Future<void> _installApk(String path) async {
    await _platform.invokeMethod<void>('installApk', {'path': path});
  }

  List<String> _downloadCandidates(String url) {
    final normalized = url.startsWith(_githubBase) ? url : url.trim();
    return [
      for (final mirror in _downloadMirrors) '$mirror$normalized',
      normalized,
    ];
  }
}

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

abstract class _SheetContent {
  Widget build(
    BuildContext context,
    Future<void> Function(BuildContext, String) openLink,
  );
}

class _SheetParagraph implements _SheetContent {
  const _SheetParagraph(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(
    BuildContext context,
    Future<void> Function(BuildContext, String) openLink,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
          ],
          Text(body),
        ],
      ),
    );
  }
}

class _SheetLink implements _SheetContent {
  const _SheetLink(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(
    BuildContext context,
    Future<void> Function(BuildContext, String) openLink,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openLink(context, url),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ),
    );
  }
}

const _eulaText = '''
1. 服务说明
YourTJ Course 是一个校园选课信息分享平台，为用户提供课程评价、排课模拟等功能。

2. 用户内容
用户在本平台发表的评价和内容应遵守法律法规和社区规范。用户保留其内容的著作权，但授予平台非独占的展示权利。

3. 使用规则
用户不得发布虚假、违法、侵权、骚扰、垃圾广告等内容。平台有权删除违规内容。

4. 免责声明
平台信息仅供参考，课程数据来源于教务系统，平台不保证数据的绝对准确性。
''';

const _aboutIntro =
    'YOURTJ选课社区为非官方网站，由同济大学在校生开发维护。选课社区目的在于让同学们了解课程的更多情况，延续“乌龙茶”选课社区精神，不想也不能代替教务处的课程评教。我们的愿景是：建立不记名、自由、简洁、高效的选课社区。';

const _aboutAnonymous = '选课社区无需登录，不存储任何个人信息，您可以放心提交测评。';

const _aboutModeration =
    '在符合社区规范的情况下，我们不修改选课社区的点评内容，也不评价内容的真实性。如果您上过某一门课程并认为网站上的点评与事实不符，欢迎提交您的意见，我们相信全面的信息会给大家最好的答案。管理员的责任仅限于维护系统稳定、删除非课程点评内容和重复发帖，并维护课程和教师信息格式，方便进行数据的批量处理。';

const _faqReviewTarget =
    '所有的课程。但如果你想帮忙，最好的是那些还没有点评的课程和老师。请不要吝啬你的好评，也不要害怕说坏话。即使是没有什么亮点的课程也值得你来写一条点评，因为“这门课很正常”也是很重要的信息。\n\n一个理想的点评应该饱含事实、尽量全面，并且清晰。请只点评自己上过的课程，列举事实，不鼓励情绪宣泄。';

const _faqPurpose = '这不是社区的主题。我们希望提供完全信息，方便同学们了解课程风格、考核标准与历史，而不是只讨论哪些课容易满绩。';

const _faqRating =
    '数据本身很容易带来错误信心。每个同学对推荐程度、工作量的判断标准不同，数字看似客观，实际很主观。内容才是这个网站存在的核心。';

const _faqModeration =
    '我们原则上不修改网站上的课程点评，也不评价内容真实性。但非课程点评信息、刷点评、侵害他人利益、违反用户所在地区法律的内容，本社区不予接受。';

const _faqCopyright =
    '提交点评时，您同意向社区提供对点评内容的永久、不可撤回、非独占、全球有效无限制的许可。您依然享有提交内容的全部版权。';

const _faqTeacher =
    '如果希望回复点评，或认为课程点评中存在虚假内容，请使用学校邮箱发信给我们，并提供希望回复或澄清的内容。确认身份后我们会协助处理。';

const _privacyIntro =
    '更新日期：2026 年 6 月\n\nYourTJ Course 尊重并保护您的隐私。本隐私政策说明我们如何收集、使用和保护您的信息。';

const _privacyCollection =
    '本应用不收集任何个人身份信息。应用首次启动时会生成一个随机 clientId，用于点赞操作的防重复与计数。此标识仅用于 API 请求处理，不做长期追踪。';

const _privacyThirdParty = '本应用不包含第三方分析 SDK、广告 SDK 或数据收集代码。';

const _privacyTransport =
    '应用向 YourTJ 运营的后端服务发送请求，以获取课程数据、提交评价、查询排课信息等。这些请求不包含可用于识别您个人身份的信息。所有网络通信使用 HTTPS 加密。';

const _privacySecurity =
    '我们不将您的数据用于广告投放、用户画像、机器学习训练或分享给第三方。评价编辑相关签名在本机完成，私钥不出设备。';

const _privacyRetention =
    '由于应用不收集个人身份信息，我们没有需要保留或删除的用户账户数据。已发表的评价内容可联系后端管理员处理。';

const _privacyChildren = '本应用面向大学生和成人用户，不针对 13 岁以下儿童，也不会故意收集儿童的个人信息。';

const _privacyChanges = '本隐私政策可能不时更新。重大变更将通过应用内公告通知您。';

const _communityGuidelinesText = '''
- 尊重他人，不进行人身攻击。
- 评价内容应真实、客观、有帮助。
- 禁止发布虚假信息或恶意差评。
- 禁止垃圾广告和刷屏行为。
- 保护个人隐私，不泄露他人信息。
- 发现违规内容请使用举报功能。
''';

const _safetyText = '''
- Release APK 明确声明 Android INTERNET 权限，用于访问真实后端。
- 评价提供举报与本机隐藏入口。
- 钱包功能暂不纳入 Flutter 测试版同步范围。
''';
