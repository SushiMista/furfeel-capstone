import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/furfeel_logo.dart';
import 'device_pairing_page.dart';
import 'dog_form_page.dart';

/// ADDED: guided first-run setup (docs/04 Onboarding): add your dog → pair the
/// harness → done, as warm animated steps instead of an empty dashboard.
/// Shown by RootShell whenever the account has no dogs yet.
class GuidedSetupPage extends StatefulWidget {
  const GuidedSetupPage({
    super.key,
    required this.repository,
    required this.onFinished,
    required this.onSignOut,
  });

  final FurFeelRepository repository;

  /// Called when setup completes (or is skipped) so the shell reloads dogs.
  final Future<void> Function() onFinished;
  final Future<void> Function() onSignOut;

  @override
  State<GuidedSetupPage> createState() => _GuidedSetupPageState();
}

class _GuidedSetupPageState extends State<GuidedSetupPage> {
  Dog? _dog;
  bool _paired = false;
  int get _step => _dog == null ? 0 : (_paired ? 2 : 1);

  Future<void> _addDog() async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => DogFormPage(repository: widget.repository)),
    );
    if (result is Dog && mounted) {
      HapticFeedback.lightImpact();
      setState(() => _dog = result);
    }
  }

  Future<void> _pairDevice() async {
    final dog = _dog;
    if (dog == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DevicePairingPage(repository: widget.repository, dog: dog),
      ),
    );
    if (!mounted) return;
    final device = await widget.repository.fetchDeviceForDog(dog.id);
    if (!mounted) return;
    if (device != null) {
      HapticFeedback.mediumImpact();
      setState(() => _paired = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = SettingsScope.of(context).profile?.firstName;

    return Scaffold(
      appBar: AppBar(
        title: const FurFeelLogo(),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => widget.onSignOut(),
            icon: Icon(Icons.logout, color: context.ff.inkMuted),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space5),
        children: [
          Text(
            firstName == null ? 'Welcome!' : 'Welcome, $firstName!',
            style: textTheme.headlineMedium,
          ).entrance(context),
          const SizedBox(height: FurFeelTokens.space2),
          Text(
            'Three small steps and FurFeel starts watching over your best friend.',
            style: textTheme.bodyMedium?.copyWith(color: context.ff.inkMuted),
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space5),
          _SetupStep(
            index: 1,
            title: 'Add your dog',
            subtitle: _dog == null
                ? 'Name, breed, photo — make it theirs.'
                : '${_dog!.name} is here!',
            done: _dog != null,
            active: _step == 0,
            onTap: _dog == null ? _addDog : null,
          ).entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space3),
          _SetupStep(
            index: 2,
            title: 'Pair the harness',
            subtitle: _paired
                ? 'Connected and ready.'
                : 'Enter the code on the FurFeel harness. You can also do this later.',
            done: _paired,
            active: _step == 1,
            onTap: _step >= 1 && !_paired ? _pairDevice : null,
          ).entrance(context, index: 3),
          const SizedBox(height: FurFeelTokens.space3),
          _SetupStep(
            index: 3,
            title: 'All set',
            subtitle: 'See how your dog is feeling, any time.',
            done: _step == 2,
            active: _step == 2,
            onTap: null,
          ).entrance(context, index: 4),
          const SizedBox(height: FurFeelTokens.space6),
          if (_step >= 1)
            ElevatedButton(
              onPressed: () => widget.onFinished(),
              child: Text(_paired ? 'Meet your dashboard' : 'Finish — pair later'),
            ).entrance(context, index: 5),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final circleColor = done
        ? context.ff.statusCalmFg
        : active
            ? context.ff.brand
            : context.ff.surfaceAlt;
    final numberColor = done || active ? context.ff.surface : context.ff.inkMuted;

    return PressScale(
      child: Material(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(FurFeelTokens.space4),
            decoration: BoxDecoration(
              border: Border.all(
                color: active ? context.ff.brand : context.ff.hairline,
                width: active ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: FurFeelTokens.motionSlow,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
                  child: Center(
                    child: done
                        ? Icon(Icons.check, size: 20, color: context.ff.surface)
                        : Text(
                            '$index',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: numberColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: FurFeelTokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: context.ff.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
