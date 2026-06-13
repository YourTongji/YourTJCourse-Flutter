import 'package:flutter/material.dart';
import 'package:m3e_loading/m3e_loading.dart';

/// Global loading indicator: Material 3 expressive morphing ring.
class GlobalLoader extends StatelessWidget {
  const GlobalLoader({
    super.key,
    this.message,
    this.size = M3ELoadingIndicator.sizeMD,
  });

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          M3ELoadingIndicator(
            size: size,
            color: scheme.primary,
          ),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
