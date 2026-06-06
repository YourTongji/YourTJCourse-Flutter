import 'package:flutter/material.dart';

class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('钱包')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('钱包能力将在后续版本接入安全存储与积分服务。', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
