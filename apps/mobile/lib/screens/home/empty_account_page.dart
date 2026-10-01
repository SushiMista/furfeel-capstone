import 'package:flutter/material.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';

class EmptyAccountPage extends StatelessWidget {
  const EmptyAccountPage({
    super.key,
    required this.onSignOut,
  });

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.pets,
                size: 64,
                color: context.ff.inkMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: FurFeelTokens.space4),
              Text(
                'No Dog Assigned Yet',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.ff.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FurFeelTokens.space3),
              Text(
                'Your veterinarian has not linked a dog profile to your account yet. Please contact your veterinary clinic for assistance.',
                style: textTheme.bodyLarge?.copyWith(
                  color: context.ff.inkMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FurFeelTokens.space6),
              FilledButton(
                onPressed: () {
                  // In a real app this might open a mailto: or tel: link.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please contact your clinic directly.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Contact Veterinarian'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
