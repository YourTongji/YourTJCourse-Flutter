import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.policy_outlined),
            title: Text('社区规范'),
            subtitle: Text('评价展示保留举报与隐藏入口'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('YourTJ 选课社区 Flutter 测试版'),
          ),
        ],
      ),
    );
  }
}
