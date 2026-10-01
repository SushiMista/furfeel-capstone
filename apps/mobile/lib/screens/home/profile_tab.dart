import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/settings_group.dart';
import 'package:furfeel_mobile/widgets/user_avatar.dart';
import 'package:furfeel_mobile/screens/settings/account_page.dart';
import 'package:furfeel_mobile/screens/dogs/care_tips_page.dart';
import 'package:furfeel_mobile/screens/dogs/dog_profile_page.dart';
import 'package:furfeel_mobile/screens/settings/partner_clinics_page.dart';
import 'package:furfeel_mobile/screens/settings/settings_page.dart';

/// Profile tab (docs/04 nav): account (→ AccountPage), settings (→
/// SettingsPage), and the owner's dogs (add/edit — Pet Creation module).
///
/// Modern-minimal, iOS Settings-flavored: a large tappable identity header
/// (name/photo behave like the "Apple ID" row -- one tap opens the full
/// account screen), then inset grouped sections with rounded surfaces and
/// hairline dividers, sign out isolated in its own destructive group.
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ff.statusHighFg),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final profile = controller.profile;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space5,
      ),
      children: [
        // ── Identity header ────────────────────────────────────────────
        SettingsGroup(
          children: [
            PressScale(
              child: InkWell(
                borderRadius: BorderRadius.circular(FurFeelTokens.radiusLg),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AccountPage(repository: repository, onSignOut: onSignOut),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FurFeelTokens.space4),
                  child: Row(
                    children: [
                      UserAvatar(profile: profile, repository: repository, radius: 32),
                      const SizedBox(width: FurFeelTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.name ?? userEmail ?? 'Your account',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile?.email ?? userEmail ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: context.ff.inkMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: context.ff.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ).entrance(context),
        const SizedBox(height: FurFeelTokens.space5),

        // ── Settings ──────────────────────────────────────────────────
        SettingsGroup(
          header: 'PREFERENCES',
          children: [
            SettingsRow(
              icon: Icons.tune,
              title: 'Settings',
              subtitle: 'Theme, units, notifications',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
            SettingsRow(
              icon: Icons.tips_and_updates_outlined,
              iconBackground: context.ff.warmSoft,
              iconColor: context.ff.warm,
              title: 'Care tips',
              subtitle: 'Guidance for everyday situations',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CareTipsPage(repository: repository),
                ),
              ),
            ),
          ],
        ).entrance(context, index: 2),
        const SizedBox(height: FurFeelTokens.space5),

        // ── My Dogs ───────────────────────────────────────────────────
        SettingsGroup(
          header: 'MY DOGS',
          children: [
            if (dogs.isEmpty)
              SettingsRow(
                icon: Icons.pets,
                title: 'No dogs yet',
                subtitle: 'Your veterinarian has not assigned a dog',
                showChevron: false,
              )
            else
              for (final dog in dogs)
                SettingsRow(
                  // Squircle in list context (docs/21 Phase 1): a squarer crop
                  // shows more of the animal at the same optical weight, and
                  // the row already carries the dog's derived tint.
                  leading: DogAvatar(
                    dog: dog,
                    repository: repository,
                    radius: 15,
                    shape: DogAvatarShape.squircle,
                  ),
                  title: dog.name,
                  subtitle: [
                    if (dog.breed != null) dog.breed!,
                    if (dog.ageYears != null)
                      '${dog.ageYears} ${dog.ageYears == 1 ? 'year' : 'years'} old',
                    dog.clinicId != null ? 'Clinic-monitored' : 'Home only',
                  ].join(' · '),
                  showChevron: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DogProfilePage(repository: repository, dog: dog),
                    ),
                  ).then((_) => onDogsChanged()),
                ),
          ],
        ).entrance(context, index: 3),
        const SizedBox(height: FurFeelTokens.space5),

        // ── Partner Clinics ────────────────────────────────────────────
        SettingsGroup(
          header: 'VETERINARY',
          children: [
            SettingsRow(
              icon: Icons.local_hospital_outlined,
              iconBackground: context.ff.statusCalmBg,
              iconColor: context.ff.statusCalmFg,
              title: 'Partner Clinics',
              subtitle: 'Clinics integrated with FurFeel',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PartnerClinicsPage(repository: repository),
                ),
              ),
            ),
          ],
        ).entrance(context, index: 4),
        const SizedBox(height: FurFeelTokens.space5),

        // ── Sign out ───────────────────────────────────────────────────
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.logout,
              title: 'Sign out',
              destructive: true,
              showChevron: false,
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ).entrance(context, index: 5),
        const SizedBox(height: FurFeelTokens.space5),

        Text(
          'FurFeel is decision support for you and your care team, never a diagnosis.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ).entrance(context, index: 6),
      ],
    );
  }
}

