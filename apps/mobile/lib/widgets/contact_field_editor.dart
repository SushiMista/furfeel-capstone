import 'package:flutter/material.dart';

import '../data/settings_controller.dart';
import '../models/models.dart';

/// Shared edit flow for the profile contact fields (Phone Number, Emergency
/// Contact): prefilled dialog → save through the repository → refresh the
/// app-wide profile in SettingsScope. Saving blank clears the field.
Future<void> editContactField(
  BuildContext context, {
  required String title,
  required String hint,
  required String? current,
  required Future<UserProfile> Function(String? value) save,
  TextInputType keyboardType = TextInputType.text,
}) async {
  final controller = TextEditingController(text: current ?? '');
  final submitted = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // No eager dispose: the dialog's exit animation still holds the controller;
  // it's short-lived and GC'd with the route.
  if (submitted == null || !context.mounted) return;

  final settings = SettingsScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final profile = await save(submitted);
    settings.setProfile(profile);
    // Replace, don't queue: back-to-back edits should confirm instantly.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(submitted.trim().isEmpty ? '$title cleared' : '$title saved'),
      behavior: SnackBarBehavior.floating,
    ));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Couldn\'t save — please check your connection and try again.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
