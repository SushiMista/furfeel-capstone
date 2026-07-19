import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// ADDED: user profile avatar — the uploaded photo (signed URL from the
/// private avatars bucket) when present, otherwise the user's initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    required this.repository,
    this.radius = 28,
  });

  final UserProfile? profile;
  final FurFeelRepository repository;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = (profile?.name.isNotEmpty ?? false)
        ? profile!.name.trim()[0].toUpperCase()
        : '?';
    final placeholder = Text(
      initial,
      style: TextStyle(
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w700,
        color: context.ff.brand,
      ),
    );
    final avatarPath = profile?.avatarPath;
    if (avatarPath == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: context.ff.brandSoft,
        child: placeholder,
      );
    }
    return FutureBuilder<String>(
      future: repository.getSignedAvatarUrl(avatarPath),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return CircleAvatar(
          radius: radius,
          backgroundColor: context.ff.brandSoft,
          foregroundImage: url == null ? null : NetworkImage(url),
          child: placeholder,
        );
      },
    );
  }
}
