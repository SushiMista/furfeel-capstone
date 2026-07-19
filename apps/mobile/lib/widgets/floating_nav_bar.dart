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
  final String label;
  final int badgeCount;
}

/// Modern-minimal floating pill nav bar: a rounded surface with a soft,
/// brand-tinted shadow that hovers above the page background instead of a
/// bar flush with the screen edges. Selection is shown by a soft pill behind
/// the icon + a bold label (word + weight, never color alone).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: FurFeelTokens.space2),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FurFeelTokens.space4,
          vertical: FurFeelTokens.space2,
        ),
        child: Container(
          height: 64,
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
          child: Row(
            children: [
              for (final (i, dest) in destinations.indexed)
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
      icon = Badge(label: Text('${destination.badgeCount}'), child: icon);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
        ),
        child: Semantics(
          label: destination.label,
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
                  horizontal: FurFeelTokens.space3,
                  vertical: FurFeelTokens.space1,
                ),
                decoration: BoxDecoration(
                  color: selected ? context.ff.brandSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(FurFeelTokens.radiusPill),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 2),
                    Text(
                      destination.label,
                      // A11y: labels scale with dynamic type but cap at 1.3×
                      // inside the fixed-height bar (Material nav-bar guidance)
                      // — the tab still reads bigger, the bar never overflows.
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: 1.3),
                      style: TextStyle(
                        fontSize: FurFeelTokens.typeLabelSize,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
