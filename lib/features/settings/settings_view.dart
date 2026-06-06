import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
                      Text('Flutter 测试版 · YourTJ选课测试'),
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
            leading: const Icon(Icons.policy_outlined),
            title: const Text('社区规范'),
            subtitle: const Text('评价支持隐藏与举报，请保持真实、克制和可验证'),
            onTap: () =>
                _showTextSheet(context, '社区规范', _communityGuidelinesText),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: const Text('安全与合规'),
            subtitle: const Text('Release 默认 HTTPS，客户端不保存后端密钥'),
            onTap: () => _showTextSheet(context, '安全与合规', _safetyText),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 YourTJ Course'),
            subtitle: const Text('同济大学选课社区移动端测试应用'),
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

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'YourTJ选课测试',
      applicationVersion: '1.0.0',
      applicationIcon: Image.asset('assets/images/app_logo.png', width: 56),
      children: const [
        Text('同济大学选课社区 Flutter Android 测试客户端。'),
        SizedBox(height: 8),
        Text('默认连接真实后端 https://jcourse.yourtj.de。'),
      ],
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

5. 隐私
本测试版不会收集不必要的个人信息，不会提交本机密钥或 .env 文件。
''';

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
- 默认 API 地址为 https://jcourse.yourtj.de。
- 客户端不保存后端密钥，不提交 .env 文件。
- 评价提供举报与本机隐藏入口。
- 钱包功能暂不纳入 Flutter 测试版同步范围。
''';
