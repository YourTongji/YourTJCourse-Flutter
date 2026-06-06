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
            subtitle: const Text('同步自 YourTJCourse-Serverless 关于页面'),
            onTap: () => _showTextSheet(context, '关于选课社区', _aboutText),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('常见问题'),
            subtitle: const Text('点评、社区管理与联系方式'),
            onTap: () => _showTextSheet(context, '常见问题', _faqText),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隐私政策'),
            subtitle: const Text('同步自 iOS 版隐私政策'),
            onTap: () => _showTextSheet(context, '隐私政策', _privacyText),
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
      applicationName: 'YourTJ Course',
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

const _aboutText = '''
简介
YOURTJ选课社区为非官方网站，由同济大学在校生开发维护。选课社区目的在于让同学们了解课程的更多情况，延续“乌龙茶”选课社区精神，不想也不能代替教务处的课程评教。我们的愿景是：建立不记名、自由、简洁、高效的选课社区。

匿名身份
选课社区无需登录，不存储任何个人信息，您可以放心提交测评。

点评管理
在符合社区规范的情况下，我们不修改选课社区的点评内容，也不评价内容的真实性。如果您上过某一门课程并认为网站上的点评与事实不符，欢迎提交您的意见，我们相信全面的信息会给大家最好的答案。

管理员的责任仅限于维护系统稳定、删除非课程点评内容和重复发帖，并维护课程和教师信息格式，方便进行数据的批量处理。

联系方式
您目前可以通过邮件 support@yourtj.de 联系我们。

致谢
YOURTJ选课社区基于 SJTU选课社区 源代码。
YOURTJ选课社区人机验证基于 BangCaptcha 源代码。
排课模拟器及高级检索基于 TONGJI-COURSE-SCHEDULER 源代码。
''';

const _faqText = '''
我该点评哪些课程？写什么？
所有的课程。但如果你想帮忙，最好的是那些还没有点评的课程和老师。请不要吝啬你的好评，也不要害怕说坏话。即使是没有什么亮点的课程也值得你来写一条点评，因为“这门课很正常”也是很重要的信息。

一个理想的点评应该饱含事实、尽量全面，并且清晰。请只点评自己上过的课程，列举事实，不鼓励情绪宣泄。

选课社区是用来找到“水课”的吗？
这不是社区的主题。我们希望提供完全信息，方便同学们了解课程风格、考核标准与历史，而不是只讨论哪些课容易满绩。

我喜欢看 1-5 星评分的数据，不喜欢看字。
数据本身很容易带来错误信心。每个同学对推荐程度、工作量的判断标准不同，数字看似客观，实际很主观。内容才是这个网站存在的核心。

选课社区谁开发和部署的？
同济大学在校（或曾经在校）生。

选课社区由谁来管理？
同济大学在校（或曾经在校）生。

我会因为在这里发表点评而被约谈吗？
不会，因为选课社区采用不记名制。

网站上的内容是否受管理？
我们原则上不修改网站上的课程点评，也不评价内容真实性。但非课程点评信息、刷点评、侵害他人利益、违反用户所在地区法律的内容，本社区不予接受。

如何界定社区内容的版权问题？
提交点评时，您同意向社区提供对点评内容的永久、不可撤回、非独占、全球有效无限制的许可。您依然享有提交内容的全部版权。

如何联系你们？
请通过邮件 support@yourtj.de 向社区提出意见和建议。

我是课程老师……
如果希望回复点评，或认为课程点评中存在虚假内容，请使用学校邮箱发信到 support@yourtj.de，并提供希望回复或澄清的内容。确认身份后我们会协助处理。
''';

const _privacyText = '''
更新日期：2026 年 6 月

YourTJ Course 尊重并保护您的隐私。本隐私政策说明我们如何收集、使用和保护您的信息。

信息收集
本应用不收集任何个人身份信息。应用首次启动时会生成一个随机 clientId，用于点赞操作的防重复与计数。此标识仅用于 API 请求处理，不做长期追踪。

第三方代码
本应用不包含第三方分析 SDK、广告 SDK 或数据收集代码。

数据传输与存储
应用向 YourTJ 运营的后端服务发送请求，以获取课程数据、提交评价、查询排课信息等。这些请求不包含可用于识别您个人身份的信息。所有网络通信使用 HTTPS 加密。

数据安全
我们不将您的数据用于广告投放、用户画像、机器学习训练或分享给第三方。评价编辑相关签名在本机完成，私钥不出设备。

数据保留与删除
由于应用不收集个人身份信息，我们没有需要保留或删除的用户账户数据。已发表的评价内容可联系后端管理员处理。

儿童隐私
本应用面向大学生和成人用户，不针对 13 岁以下儿童，也不会故意收集儿童的个人信息。

政策变更
本隐私政策可能不时更新。重大变更将通过应用内公告通知您。

联系我们
GitHub Issues：https://github.com/YourTongji/YourTJCourse-Flutter/issues
项目仓库：https://github.com/YourTongji/YourTJCourse-Flutter
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
