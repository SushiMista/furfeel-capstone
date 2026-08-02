import 'package:flutter/material.dart';

import 'package:furfeel_mobile/data/furfeel_repository.dart';
import 'package:furfeel_mobile/data/settings_controller.dart';
import 'package:furfeel_mobile/models/models.dart';
import 'package:furfeel_mobile/theme/furfeel_tokens.dart';
import 'package:furfeel_mobile/util/motion.dart';
import 'package:furfeel_mobile/widgets/contact_field_editor.dart';
import 'package:furfeel_mobile/widgets/dog_avatar.dart';
import 'package:furfeel_mobile/widgets/settings_group.dart';
import 'package:furfeel_mobile/widgets/user_avatar.dart';
import 'package:furfeel_mobile/screens/settings/account_page.dart';
import 'package:furfeel_mobile/screens/dogs/care_tips_page.dart';
import 'package:furfeel_mobile/screens/dogs/device_pairing_page.dart';
import 'package:furfeel_mobile/screens/dogs/dog_form_page.dart';
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

  Future<void> _openForm(BuildContext context, {Dog? dog}) async {
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(builder: (_) => DogFormPage(repository: repository, dog: dog)),
    );
    if (result != null) await onDogsChanged();
  }

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
        PressScale(
          child: InkWell(
            borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    AccountPage(repository: repository, onSignOut: onSignOut),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FurFeelTokens.space3),
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
                          style: Theme.of(context).textTheme.titleLarge,
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
        ).entrance(context),
        const SizedBox(height: FurFeelTokens.space4),

        // ── Account Info ───────────────────────────────────────────────
        SettingsGroup(
          header: 'ACCOUNT INFO',
          children: [
            SettingsRow(
              icon: Icons.phone_outlined,
              title: 'Phone Number',
              subtitle: profile?.phone ?? 'Not set',
              showChevron: true,
              onTap: () => editContactField(
                context,
                title: 'Phone Number',
                hint: '+63 9XX XXX XXXX',
                keyboardType: TextInputType.phone,
                current: profile?.phone,
                save: repository.updateMyPhone,
              ),
            ),
            SettingsRow(
              icon: Icons.emergency_outlined,
              iconBackground: context.ff.warmSoft,
              iconColor: context.ff.warm,
              title: 'Emergency Contact',
              subtitle: profile?.emergencyContact ?? 'Not set',
              showChevron: true,
              onTap: () => editContactField(
                context,
                title: 'Emergency Contact',
                hint: 'Name and number',
                current: profile?.emergencyContact,
                save: repository.updateMyEmergencyContact,
              ),
            ),
            SettingsRow(
              icon: Icons.calendar_month_outlined,
              iconBackground: context.ff.statusCalmBg,
              iconColor: context.ff.statusCalmFg,
              title: 'Member Since',
              subtitle: profile == null ? '—' : _monthYear(profile.createdAt),
              showChevron: false,
            ),
          ],
        ).entrance(context, index: 1),
        const SizedBox(height: FurFeelTokens.space5),

        // ── Settings ──────────────────────────────────────────────────
        SettingsGroup(
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
          headerAction: TextButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
          children: [
            if (dogs.isEmpty)
              SettingsRow(
                icon: Icons.pets,
                title: 'No dogs yet',
                subtitle: 'Add a dog to start monitoring',
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
                  trailing: IconButton(
                    tooltip: 'Harness',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.sensors, color: context.ff.inkMuted),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DevicePairingPage(repository: repository, dog: dog),
                      ),
                    ),
                  ),
                  onTap: () => _openForm(context, dog: dog),
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

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthYear(DateTime date) => '${_monthNames[date.month - 1]} ${date.year}';
