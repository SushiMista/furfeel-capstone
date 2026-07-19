import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import '../widgets/user_avatar.dart';
import '../util/errors.dart';

/// ADDED: Profile / Account (docs/04): name, email, profile photo
/// (users.avatar_path → avatars bucket), change password, sign out, delete
/// account.
class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.repository,
    required this.onSignOut,
  });

  final FurFeelRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on FurFeelDataException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(actionErrorMessage(e, 'That change'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() => _run(() async {
        final file =
            await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (file == null) return;
        final bytes = await file.readAsBytes();
        final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
        final profile = await widget.repository.setMyAvatar(bytes, extension);
        if (!mounted) return;
        HapticFeedback.lightImpact();
        SettingsScope.of(context).setProfile(profile);
      });

  Future<void> _editName() async {
    final controller = SettingsScope.of(context);
    final nameController = TextEditingController(text: controller.profile?.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await _run(() async {
      final profile = await widget.repository.updateMyName(newName);
      if (!mounted) return;
      SettingsScope.of(context).setProfile(profile);
    });
  }

  Future<void> _changePassword() async {
    final passwordController = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: TextField(
          controller: passwordController,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(passwordController.text),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (newPassword == null || !mounted) return;
    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password needs at least 8 characters.')),
      );
      return;
    }
    await _run(() async {
      await widget.repository.changePassword(newPassword);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed')),
      );
    });
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes your account and dog profiles. Monitoring history that '
          'belongs to a clinic record is kept, as explained in Privacy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.ff.statusHighFg),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await widget.repository.deleteAccount();
      await widget.onSignOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final profile = controller.profile;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    UserAvatar(
                      profile: profile,
                      repository: widget.repository,
                      radius: 44,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: context.ff.brand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _changePhoto,
                          // A11y: icon-only control needs a spoken name.
                          child: Semantics(
                            label: 'Change profile photo',
                            button: true,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 18,
                                color: context.ff.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FurFeelTokens.space3),
                Text(profile?.name ?? '', style: textTheme.headlineMedium),
                Text(profile?.email ?? '', style: textTheme.bodySmall),
              ],
            ),
          ).entrance(context),
          const SizedBox(height: FurFeelTokens.space6),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.badge_outlined, color: context.ff.brand),
                  title: const Text('Name'),
                  subtitle: Text(profile?.name ?? '—'),
                  trailing: Icon(Icons.chevron_right, color: context.ff.inkMuted),
                  onTap: _busy ? null : _editName,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.mail_outline, color: context.ff.brand),
                  title: const Text('Email'),
                  subtitle: Text(profile?.email ?? '—'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.password_outlined, color: context.ff.brand),
                  title: const Text('Change password'),
                  trailing: Icon(Icons.chevron_right, color: context.ff.inkMuted),
                  onTap: _busy ? null : _changePassword,
                ),
              ],
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space5),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => widget.onSignOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ).entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space3),
          TextButton(
            onPressed: _busy ? null : _deleteAccount,
            child: Text(
              'Delete account',
              style: TextStyle(color: context.ff.statusHighFg),
            ),
          ).entrance(context, index: 3),
        ],
      ),
    );
  }
}
