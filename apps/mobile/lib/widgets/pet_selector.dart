import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';
import 'dog_avatar.dart';

/// The board's "My Pets" row (docs/21 Redesign Plan §4, Phase 4): a horizontal
/// strip of tinted squircle avatars with the name beneath, plus a trailing add
/// affordance.
///
/// It composes [DogAvatar] rather than re-deriving tints or shapes — a dog wears
/// the same tint here as on Home and its profile because both read it from
/// [dogTint].
class PetSelector extends StatelessWidget {
  const PetSelector({
    super.key,
    required this.dogs,
    required this.repository,
    required this.onSelect,
    this.onAdd,
    this.selectedId,
  });

  final List<Dog> dogs;
  final FurFeelRepository repository;

  /// Tapping an avatar.
  final void Function(Dog dog) onSelect;

  /// Trailing add tile. Omitted when null (e.g. a read-only context).
  final VoidCallback? onAdd;

  /// Draws a brand ring around the matching avatar. Null selects nothing.
  final String? selectedId;

  static const double _avatarRadius = 28;
  // Wide enough for a two-word name to wrap to two lines without shoving its
  // neighbour; the avatars stay evenly spaced regardless of name length.
  static const double _tileWidth = 76;

  @override
  Widget build(BuildContext context) {
    // Ring padding (4) + avatar (radius*2) + gap + two caption lines. Fixed so
    // the horizontal ListView has a bounded cross-axis.
    const height = _avatarRadius * 2 + 4 + FurFeelTokens.space2 + 40;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: FurFeelTokens.space1),
        itemCount: dogs.length + (onAdd == null ? 0 : 1),
        separatorBuilder: (_, _) =>
            const SizedBox(width: FurFeelTokens.space2),
        itemBuilder: (context, i) {
          if (i == dogs.length) return _AddTile(onTap: onAdd!);
          final dog = dogs[i];
          return _PetTile(
            dog: dog,
            repository: repository,
            selected: dog.id == selectedId,
            onTap: () => onSelect(dog),
          );
        },
      ),
    );
  }
}

class _PetTile extends StatelessWidget {
  const _PetTile({
    required this.dog,
    required this.repository,
    required this.selected,
    required this.onTap,
  });

  final Dog dog;
  final FurFeelRepository repository;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    final avatar = DogAvatar(
      dog: dog,
      repository: repository,
      radius: PetSelector._avatarRadius,
      shape: DogAvatarShape.squircle,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: 'View ${dog.name}',
      excludeSemantics: true,
      child: PressScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: SizedBox(
            width: PetSelector._tileWidth,
            child: Column(
              children: [
                // The ring is the only selection signal that survives on a
                // photo avatar — a background tint change would be hidden
                // behind the picture.
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                        FurFeelTokens.radiusMd + 3),
                    border: Border.all(
                      color: selected ? p.brand : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: avatar,
                ),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  dog.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? p.brandInk : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ff;
    const size = PetSelector._avatarRadius * 2;

    return Semantics(
      button: true,
      label: 'Add a dog',
      excludeSemantics: true,
      child: PressScale(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusMd),
          child: SizedBox(
            width: PetSelector._tileWidth,
            child: Column(
              children: [
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.brandSoft,
                    borderRadius:
                        BorderRadius.circular(FurFeelTokens.radiusMd),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Icon(Icons.add, color: p.brand),
                ),
                const SizedBox(height: FurFeelTokens.space2),
                Text(
                  'Add',
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    color: p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
