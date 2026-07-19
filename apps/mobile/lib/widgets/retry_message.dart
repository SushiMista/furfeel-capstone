import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// Shared pull-to-refresh message view for empty and error states (promoted
/// from RootShell's private _EmptyMessage during the error-state audit so
/// every self-loading page fails the same way).
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        children: [
          const SizedBox(height: 80),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.ff.inkMuted),
          ),
        ],
      ),
    );
  }
}
