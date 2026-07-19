import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Dog profile avatar: the uploaded photo (signed URL from the private media
/// bucket) when present, otherwise a friendly emoji placeholder.
class DogAvatar extends StatelessWidget {
  const DogAvatar({
    super.key,
    required this.dog,
    required this.repository,
    this.radius = 28,
    this.backgroundColor,
  });

  final Dog dog;
  final FurFeelRepository repository;
  final double radius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final photoPath = dog.photoPath;
    final bg = backgroundColor ?? context.ff.brandSoft;
    if (photoPath == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(Icons.pets, size: radius, color: context.ff.brand),
      );
    }
    return FutureBuilder<String>(
      future: repository.getSignedMediaUrl(photoPath),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return CircleAvatar(
          radius: radius,
          backgroundColor: bg,
          foregroundImage: url == null ? null : NetworkImage(url),
          child: Icon(Icons.pets, size: radius, color: context.ff.brand),
        );
      },
    );
  }
}
