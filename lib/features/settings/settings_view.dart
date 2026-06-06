import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          const ListTile(
            leading: Icon(Icons.policy_outlined),
            title: Text('社区规范'),
            subtitle: Text('评价支持隐藏与举报，请保持真实、克制和可验证'),
          ),
          const ListTile(
            leading: Icon(Icons.feedback_outlined),
            title: Text('反馈'),
            subtitle: Text('通过 GitHub Issues 反馈 Flutter 测试版问题'),
          ),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('安全与合规'),
            subtitle: Text('Release 默认 HTTPS，客户端不保存后端密钥'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('同济大学选课社区移动端测试应用'),
          ),
        ],
      ),
    );
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
}
