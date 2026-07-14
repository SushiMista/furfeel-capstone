import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/dog_avatar.dart';
import '../widgets/user_avatar.dart';
import 'account_page.dart';
import 'device_pairing_page.dart';
import 'dog_form_page.dart';
import 'settings_page.dart';

/// Profile tab (docs/04 nav): account (→ AccountPage), settings (→
/// SettingsPage), and the owner's dogs (add/edit — Pet Creation module).
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.repository,
    required this.dogs,
    required this.userEmail,
    required this.onDogsChanged,
    required this.onSignOut,
  });

  final FurFeelRepository repository;
  final List<Dog> dogs;
  final String? userEmail;

  /// Called after any create/edit/delete so the shell reloads its dog list.
  final Future<void> Function() onDogsChanged;
  final Future<void> Function() onSignOut;

  Future<void> _openForm(BuildContext context, {Dog? dog}) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => DogFormPage(repository: repository, dog: dog)),
    );
    if (result != null) await onDogsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final controller = SettingsScope.of(context);
    final profile = controller.profile;

    return ListView(
      padding: const EdgeInsets.all(FurFeelTokens.space4),
      children: [
        // ADDED: account card opens the full Profile/Account page.
        PressScale(
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: FurFeelTokens.space4,
                vertical: FurFeelTokens.space2,
              ),
              leading: UserAvatar(profile: profile, repository: repository, radius: 24),
              title: Text(
                profile?.name ?? userEmail ?? 'Your account',
                style: textTheme.titleMedium,
              ),
              subtitle: Text(profile?.email ?? userEmail ?? ''),
              trailing: Icon(Icons.chevron_right, color: FurFeelTokens.inkMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AccountPage(repository: repository, onSignOut: onSignOut),
                ),
              ),
            ),
          ),
        ).entrance(context),
        const SizedBox(height: FurFeelTokens.space3),
        PressScale(
          child: Card(
            child: ListTile(
              leading: Icon(Icons.tune, color: FurFeelTokens.brand),
              title: const Text('Settings'),
              subtitle: const Text('Theme, units, notifications'),
              trailing: Icon(Icons.chevron_right, color: FurFeelTokens.inkMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
          ),
        ).entrance(context, index: 1),
        const SizedBox(height: FurFeelTokens.space5),
        Row(
          children: [
            Expanded(child: Text('MY DOGS', style: textTheme.labelSmall)),
            TextButton.icon(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a dog'),
            ),
          ],
        ).entrance(context, index: 2),
        const SizedBox(height: FurFeelTokens.space2),
        Card(
          child: Column(
            children: [
              for (final (i, dog) in dogs.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: DogAvatar(dog: dog, repository: repository, radius: 20),
                  title: Text(dog.name),
                  subtitle: Text(
                    [
                      if (dog.breed != null) dog.breed!,
                      if (dog.ageYears != null)
                        '${dog.ageYears} ${dog.ageYears == 1 ? 'year' : 'years'} old',
                      dog.clinicId != null ? 'Clinic-monitored' : 'Home only',
                    ].join(' · '),
                  ),
                  trailing: Wrap(
                    spacing: FurFeelTokens.space1,
                    children: [
                      IconButton(
                        tooltip: 'Harness',
                        icon: Icon(Icons.sensors, color: FurFeelTokens.inkMuted),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DevicePairingPage(repository: repository, dog: dog),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        icon: Icon(Icons.edit_outlined, color: FurFeelTokens.inkMuted),
                        onPressed: () => _openForm(context, dog: dog),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ).entrance(context, index: 3),
        const SizedBox(height: FurFeelTokens.space5),
        Text(
          'FurFeel is decision support for you and your care team — never a diagnosis.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ).entrance(context, index: 4),
      ],
    );
  }
}
