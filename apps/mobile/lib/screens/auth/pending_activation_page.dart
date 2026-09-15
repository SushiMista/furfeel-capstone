import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/furfeel_theme.dart';
import '../../theme/furfeel_tokens.dart';

class PendingActivationPage extends StatelessWidget {
  const PendingActivationPage({
    super.key,
    required this.onCheckActivation,
    required this.onSignOut,
  });

  final VoidCallback onCheckActivation;
  final VoidCallback onSignOut;

  void _launchMerckManual() async {
    final url = Uri.parse('https://www.merckvetmanual.com/dog-owners');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: context.ff.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
              const Spacer(flex: 1),
              
              // Cute Visual Placeholder
              Center(
                child: Icon(
                  Icons.pets,
                  size: 100,
                  color: context.ff.brand,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Almost there!',
                style: textTheme.headlineMedium?.copyWith(color: context.ff.ink, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Contact your veterinarian administrator to verify and activate your account. '
                'Once activated, you will be able to access the full features of the app.',
                style: textTheme.bodyLarge?.copyWith(color: context.ff.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Care Tips Button
              InkWell(
                onTap: _launchMerckManual,
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.ff.brandSoft,
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
                    border: Border.all(color: context.ff.brand.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book, color: context.ff.brandStrong, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Canine Care Tips',
                              style: textTheme.titleMedium?.copyWith(color: context.ff.brandStrong, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View the Merck Vet Manual while you wait',
                              style: textTheme.bodyMedium?.copyWith(color: context.ff.brandStrong),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: context.ff.brandStrong, size: 16),
                    ],
                  ),
                ),
              ),
              
              const Spacer(flex: 2),

              ElevatedButton(
                onPressed: onCheckActivation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.ff.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
                  ),
                ),
                child: const Text(
                  'I have been activated',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
