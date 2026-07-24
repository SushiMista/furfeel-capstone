import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';
import '../util/motion.dart';

class FloatingNavDestination {
  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Not rendered — the bar is icon-only. This is the accessible name the
  /// item is announced and found by, so it must stay set and meaningful.
  final String label;

  final int badgeCount;
}

/// Modern-minimal floating pill nav bar: a rounded surface with a soft,
/// brand-tinted shadow that hovers above the page background instead of a
/// bar flush with the screen edges.
///
/// Icon-only by choice. Selection never rides on colour alone: the selected
/// item swaps to its *filled* glyph and gains a soft brand pill behind it, so
/// it is distinguishable without colour vision. Labels are still carried on
/// every destination and exposed through [Semantics], so screen readers
/// announce the same words the bar no longer draws.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.detachLast = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;

  /// Renders the final destination as its own round box beside the pill
  /// instead of a fifth item inside it — a destination that is a different
  /// *kind* of thing (messaging, not a view switch) reads better detached.
  /// Indices are unchanged — the detached item is still `destinations.length - 1`.
  final bool detachLast;

  @override
  Widget build(BuildContext context) {
    final pillDestinations =
        detachLast ? destinations.sublist(0, destinations.length - 1) : destinations;

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: FurFeelTokens.space2),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4,
          vertical: FurFeelTokens.space2,
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavSurface(
                child: Row(
                  children: [
                    for (final (i, dest) in pillDestinations.indexed)
                      Expanded(
                        child: _FloatingNavItem(
                          destination: dest,
                          selected: i == selectedIndex,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (detachLast) ...[
              const SizedBox(width: FurFeelTokens.space3),
              _NavSurface(
                // Square-ish so the detached box reads as one tap target, not
                // a cut-off pill; the label still rides under the icon.
                width: 64,
                child: _FloatingNavItem(
                  destination: destinations.last,
                  selected: selectedIndex == destinations.length - 1,
                  onTap: () => onDestinationSelected(destinations.length - 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The floating surface itself — same height, radius, hairline and lifted
/// shadow whether it holds the tab row or the detached action.
class _NavSurface extends StatelessWidget {
  const _NavSurface({required this.child, this.width});

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: width,
      decoration: BoxDecoration(
        color: context.ff.surface,
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        border: Border.all(color: context.ff.hairline),
        boxShadow: [
          BoxShadow(
            color: context.ff.ink.withValues(alpha: 0.10),
            offset: const Offset(0, 10),
            blurRadius: 28,
            spreadRadius: -6,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.ff.brandStrong : context.ff.inkMuted;

    Widget icon = Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 22,
      color: color,
    );
    if (destination.badgeCount > 0) {
      // The count is folded into this item's accessible name below, so the
      // badge's own text is excluded — otherwise the merged node announces a
      // bare trailing number ("Alerts 3") instead of a readable phrase.
      icon = ExcludeSemantics(
        child: Badge(label: Text('${destination.badgeCount}'), child: icon),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        ),
        child: Semantics(
          // Icon-only bar: this is the ONLY place the destination's name
          // exists, so it carries the badge count too.
          label: destination.badgeCount > 0
              ? '${destination.label}, ${destination.badgeCount} new'
              : destination.label,
          selected: selected,
          button: true,
          child: SizedBox(
            height: double.infinity,
            child: Center(
              child: AnimatedContainer(
                duration:
                    context.reduceMotion ? Duration.zero : FurFeelTokens.motionFast,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: FurFeelTokens.space4,
                  vertical: FurFeelTokens.space2,
                ),
                decoration: BoxDecoration(
                  color: selected ? context.ff.brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
