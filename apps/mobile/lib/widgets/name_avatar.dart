import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../theme/furfeel_tokens.dart';

/// Avatar for a sender we only know by name + optional photo path (a joined
/// `name, avatar_path` row — vet notes, media messages, media submissions),
/// as opposed to [UserAvatar] which takes a full [UserProfile]. Same visual
/// language: the uploaded photo when present, otherwise the initial.
class NameAvatar extends StatelessWidget {
  const NameAvatar({
    super.key,
    required this.name,
    required this.repository,
    this.avatarPath,
    this.radius = 18,
  });

  final String name;
  final String? avatarPath;
  final FurFeelRepository repository;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final placeholder = Text(
      initial,
      style: TextStyle(
        fontSize: radius * 0.85,
        fontWeight: FontWeight.w700,
        color: context.ff.brand,
      ),
    );
    final path = avatarPath;
    if (path == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: context.ff.brandSoft,
        child: placeholder,
      );
    }
    return FutureBuilder<String>(
      future: repository.getSignedAvatarUrl(path),
      builder: (context, snapshot) => CircleAvatar(
        radius: radius,
        backgroundColor: context.ff.brandSoft,
        foregroundImage: snapshot.data == null ? null : NetworkImage(snapshot.data!),
        child: placeholder,
      ),
    );
  }
}
