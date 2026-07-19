import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../util/errors.dart';

/// Current data-collection policy version (docs/12). Bumping this makes every
/// existing user re-consent: the consents table stores one row per accepted
/// version, so old acceptances stay on record.
const kConsentPolicyVersion = '2026-07-17.v1';

/// Data-collection consent gate (docs/12). Shown after sign-in until the
/// current policy version is accepted; monitoring data and media features
/// stay locked behind it.
class ConsentPage extends StatefulWidget {
  const ConsentPage({
    super.key,
    required this.repository,
    required this.onAccepted,
    required this.onSignOut,
  });

  final FurFeelRepository repository;
  final VoidCallback onAccepted;
  final Future<void> Function() onSignOut;

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.acceptConsent(kConsentPolicyVersion);
      if (mounted) widget.onAccepted();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = actionErrorMessage(e, 'Saving your consent');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              children: [
                const SizedBox(height: FurFeelTokens.space5),
                Icon(Icons.privacy_tip_outlined, size: 40, color: context.ff.brand)
                    .entrance(context),
                const SizedBox(height: FurFeelTokens.space4),
                Text('Before we start monitoring',
                        textAlign: TextAlign.center, style: textTheme.headlineMedium)
                    .entrance(context, index: 1),
                const SizedBox(height: FurFeelTokens.space3),
                Text(
                  'FurFeel collects data so you and your clinic can keep an eye '
                  'on your dog. Please review what\'s collected and agree to '
                  'continue.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ).entrance(context, index: 2),
                const SizedBox(height: FurFeelTokens.space5),
                const _ConsentItem(
                  icon: Icons.sensors,
                  title: 'Harness readings',
                  body: 'Heart rate, breathing, temperature, movement, and the '
                      'air around your dog, sent continuously while the harness '
                      'is worn. Readings are kept to build your dog\'s history.',
                ),
                const _ConsentItem(
                  icon: Icons.photo_camera_outlined,
                  title: 'Photos and videos you share',
                  body: 'Observations you submit go to your clinic for context. '
                      'They\'re never used by the automatic stress detection.',
                ),
                const _ConsentItem(
                  icon: Icons.local_hospital_outlined,
                  title: 'Shared with your chosen clinic',
                  body: 'If you link a clinic, its care team sees your dog\'s '
                      'readings and can respond. Unlink anytime in the dog\'s '
                      'profile.',
                ),
                const _ConsentItem(
                  icon: Icons.info_outline,
                  title: 'Support, not a vet',
                  body: 'FurFeel highlights patterns to talk over with your '
                      'clinic. It never makes a medical assessment of your dog.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: FurFeelTokens.space3),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall
                          ?.copyWith(color: context.ff.statusHighOwner)),
                ],
                const SizedBox(height: FurFeelTokens.space5),
                ElevatedButton(
                  onPressed: _busy ? null : _accept,
                  child: Text(_busy ? 'Saving…' : 'I agree — start monitoring'),
                ).entrance(context, index: 3),
                const SizedBox(height: FurFeelTokens.space3),
                TextButton(
                  onPressed: _busy ? null : () => widget.onSignOut(),
                  child: const Text('Not now — sign out'),
                ),
                const SizedBox(height: FurFeelTokens.space3),
                Text(
                  'Policy version $kConsentPolicyVersion. If the policy changes, '
                  'we\'ll ask again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  const _ConsentItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FurFeelTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.ff.brandSoft,
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
            ),
            child: Icon(icon, size: 20, color: context.ff.brand),
          ),
          const SizedBox(width: FurFeelTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
