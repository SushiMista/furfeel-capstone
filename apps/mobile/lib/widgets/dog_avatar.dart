import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

/// Shape of the photo frame (docs/21 Redesign Plan §4, Phase 1).
enum DogAvatarShape {
  /// Default. Inline use — list leading slots, chat headers, compact rows.
  circle,

  /// Rounded square. The pet-selector row and any grid of dogs, where a
  /// squarer crop shows more of the animal at the same optical weight.
  squircle,

  /// Arch — rounded top, squared-off base. The board's signature shape,
  /// reserved for hero and profile moments so it stays a brand note rather
  /// than a default.
  arch,
}

/// Stable across sessions, devices, and Dart versions.
///
/// [String.hashCode] would be the obvious choice and is the wrong one: Dart
/// makes no promise that it is consistent between runs, so a dog could come
/// back a different colour after a restart. Tint is part of how an owner
/// recognises their dog in a list, so it has to be as stable as the name.
int _stableHash(String s) {
  var h = 0;
  for (final unit in s.codeUnits) {
    h = (h * 31 + unit) & 0x7FFFFFFF;
  }
  return h;
}

/// The cool tinted ground for a given dog (docs/19 "Pet photography grounds").
///
/// Derived from `dog.id`, never from list position (which reorders) or
/// [Random] (which flickers on every rebuild). Exposed so other surfaces —
/// the pet selector, chat headers — can match a dog's tint without
/// duplicating the derivation.
Color dogTint(BuildContext context, Dog dog) {
  final p = context.ff;
  final tints = [p.tintBlue, p.tintTeal, p.tintPeriwinkle, p.tintSlate];
  return tints[_stableHash(dog.id) % tints.length];
}

/// Dog profile avatar: the uploaded photo (signed URL from the private media
/// bucket) when present, otherwise a friendly mark on the dog's tinted ground.
///
/// The placeholder is deliberately not a grey box. Photo coverage will always
/// be partial, and for some owners the placeholder is the permanent state —
/// so it gets the same tinted treatment as a real photo and is meant to look
/// intentional rather than missing (docs/21 §5).
class DogAvatar extends StatefulWidget {
  const DogAvatar({
    super.key,
    required this.dog,
    required this.repository,
    this.radius = 28,
    this.backgroundColor,
    this.shape = DogAvatarShape.circle,
  });

  final Dog dog;
  final FurFeelRepository repository;
  final double radius;
  final Color? backgroundColor;
  final DogAvatarShape shape;

  @override
  State<DogAvatar> createState() => _DogAvatarState();
}

class _DogAvatarState extends State<DogAvatar> {
  Future<String>? _urlFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture();
  }

  @override
  void didUpdateWidget(DogAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dog.photoPath != widget.dog.photoPath) {
      _loadFuture();
    }
  }

  void _loadFuture() {
    final path = widget.dog.photoPath;
    _urlFuture = path == null ? null : widget.repository.getSignedMediaUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? dogTint(context, widget.dog);

    if (_urlFuture == null) return _frame(context, bg, null);

    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) => _frame(context, bg, snapshot.data),
    );
  }

  Widget _frame(BuildContext context, Color bg, String? url) {
    // The friendly line-art placeholder (ADR-023), tinted from a token so it
    // matches the dog's ink on the tinted ground — a warmer read than the old
    // Icons.pets glyph, and consistent everywhere a dog has no photo.
    final mark = SvgPicture.asset(
      'assets/illustrations/placeholder_pet.svg',
      width: widget.radius * 1.35,
      height: widget.radius * 1.35,
      colorFilter: ColorFilter.mode(context.ff.brandInk, BlendMode.srcIn),
    );

    if (widget.shape == DogAvatarShape.circle) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        foregroundImage: url == null ? null : NetworkImage(url),
        child: mark,
      );
    }

    final width = widget.radius * 2;
    // The arch is taller than it is wide — that vertical proportion is what
    // makes it read as an arch rather than a rounded rectangle.
    final height = widget.shape == DogAvatarShape.arch ? widget.radius * 2.6 : width;
    final borderRadius = widget.shape == DogAvatarShape.arch
        ? BorderRadius.vertical(
            top: Radius.circular(widget.radius),
            bottom: const Radius.circular(FurFeelTokens.radiusMd),
          )
        : BorderRadius.circular(FurFeelTokens.radiusMd);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: borderRadius,
        image: url == null
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      // The mark shows only while there is no photo, so a slow load leaves the
      // placeholder in place rather than flashing an empty tinted box.
      child: url == null ? Center(child: mark) : null,
    );
  }
}
