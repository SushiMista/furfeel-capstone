import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import 'dog_avatar.dart' show DogAvatarShape;

/// A framed brand photo for **generic** slots — onboarding, welcome, marketing.
///
/// Never use this for a specific dog's identity (profile, avatar, cards): a
/// stock or generated photo in an identity slot invites the owner to think
/// they are looking at their own dog (ADR-023). Those slots use the owner's
/// upload or the tinted placeholder instead.
///
/// The image is a bundled asset. Until a curated photo is dropped in, the
/// [errorBuilder] path shows the tinted ground plus a mark, so the frame looks
/// intentional rather than broken — the same treatment a photoless dog gets.
class BrandPhotoFrame extends StatelessWidget {
  const BrandPhotoFrame({
    super.key,
    required this.asset,
    this.shape = DogAvatarShape.arch,
    this.width = 200,
    this.tint,
    this.semanticLabel,
    this.fallbackIcon = Icons.pets,
  });

  /// Bundled asset path, e.g. `assets/photos/welcome_hero.jpg`.
  final String asset;

  final DogAvatarShape shape;

  /// Frame width. Arch frames derive a taller height from it.
  final double width;

  /// Overrides the ground tint. Defaults to `tintBlue`.
  final Color? tint;

  /// Real description for a meaningful photo; null marks it decorative.
  final String? semanticLabel;

  /// Shown on the tinted ground when the asset isn't present. Defaults to the
  /// pet mark; onboarding passes each slide's own icon so the fallback stays
  /// meaningful before photos are sourced.
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final bg = tint ?? p.tintBlue;
    // The arch is taller than it is wide — that proportion is what makes it
    // read as an arch rather than a rounded rectangle (mirrors DogAvatar).
    final height = shape == DogAvatarShape.arch ? width * 1.3 : width;
    final borderRadius = switch (shape) {
      DogAvatarShape.arch => BorderRadius.vertical(
          top: Radius.circular(width / 2),
          bottom: const Radius.circular(FurFeelTokens.radiusLg),
        ),
      DogAvatarShape.circle => BorderRadius.circular(width / 2),
      DogAvatarShape.squircle => BorderRadius.circular(FurFeelTokens.radiusLg),
    };

    final fallback = Center(
      child: Icon(fallbackIcon, size: width * 0.34, color: p.brandInk),
    );

    return Semantics(
      image: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel == null,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: bg, borderRadius: borderRadius),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          // A missing asset (none curated yet) falls back to the tinted mark
          // instead of a broken-image glyph.
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
