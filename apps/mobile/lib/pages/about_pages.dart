import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// ADDED: the informational pages behind Settings (docs/04: About, Privacy,
/// "How FurFeel works" — reinforcing decision-support-not-diagnosis).

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'How FurFeel works',
      sections: const [
        (
          'The harness listens',
          'A lightweight harness reads your dog\'s heart rate, breathing, '
              'temperature, movement, and posture, plus the temperature and '
              'humidity around them, and sends it securely over Wi-Fi.',
        ),
        (
          'FurFeel looks for patterns',
          'A transparent set of rules, tuned with veterinary input, turns those '
              'readings into one of four stress levels: calm, mild, moderate, or '
              'high. You can always see which readings drove the result.',
        ),
        (
          'You hear about what matters',
          'When stress reaches moderate or high, or the harness goes quiet, '
              'FurFeel notifies you and your clinic — so a person, not an app, '
              'decides what to do next.',
        ),
        (
          'Support, never a diagnosis',
          'FurFeel is decision support. It never diagnoses, and your photos and '
              'videos are context for your care team only — they never feed the '
              'stress calculation.',
        ),
      ],
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Privacy',
      sections: const [
        (
          'Your data is yours',
          'Your account sees only your own dogs. Clinic staff see a dog only '
              'while it\'s linked to their clinic. Every rule is enforced by the '
              'database itself, not just the app.',
        ),
        (
          'What FurFeel stores',
          'Harness readings, the stress levels computed from them, alerts, and '
              'anything you add yourself — dog profiles, photos, and notes. '
              'Media is stored privately and shared only with your clinic.',
        ),
        (
          'Why readings are kept',
          'Monitoring history is part of your dog\'s clinic record, so readings '
              'are kept even if a profile is removed. That history is what makes '
              'trends and vet review possible.',
        ),
        (
          'Questions',
          'Ask your clinic, or write to privacy@furfeel.example — we\'ll answer '
              'plainly.',
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'About FurFeel',
      sections: const [
        (
          'FurFeel',
          'Real-time stress monitoring for dogs — built for owners and '
              'veterinary clinics to share one honest picture of how a dog is '
              'doing.',
        ),
        (
          'Our promise',
          'Plain language, transparent reasoning, and a person in the loop. '
              'FurFeel supports decisions; it never makes them for you.',
        ),
        ('Version', 'FurFeel for owners, version 1.0.'),
      ],
    );
  }
}

class _InfoScaffold extends StatelessWidget {
  const _InfoScaffold({required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        itemCount: sections.length,
        separatorBuilder: (_, i) => const SizedBox(height: FurFeelTokens.space3),
        itemBuilder: (context, i) {
          final (heading, body) = sections[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: textTheme.titleMedium),
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(body, style: textTheme.bodyMedium),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
