import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'furfeel_tokens.dart';

/// Maps the FurFeel token palette onto a shadcn_flutter [shadcn.ThemeData], so
/// individual shadcn components can be piloted inside specific widgets
/// without adopting `ShadcnApp` as the app root (that would mean replacing
/// `MaterialApp`, re-deriving the fade-through page transition, and rewriting
/// every `MaterialApp`-wrapped test — see docs/02 ADR-017). shadcn_flutter's
/// `Theme`/`ComponentTheme` are plain `InheritedTheme`s with no dependency on
/// `WidgetsApp`, so a local `shadcn.Theme` scope is enough for any component
/// whose `build()` only reads `Theme.of`/`ComponentTheme.maybeOf` (verified
/// against the installed 0.0.53 source for Card, Divider, and NumberTicker
/// before relying on it here).
///
/// docs/19 stays authoritative for color: every value below is read via
/// `context.ff` (the resolved `FurFeelPalette`, light or dark), never a
/// shadcn stock palette (zinc/slate/etc).
shadcn.ThemeData furFeelShadcnTheme(material.BuildContext context) {
  final palette = context.ff;
  final isDark = material.Theme.of(context).brightness == material.Brightness.dark;
  final onBrand = isDark ? palette.bg : palette.surface;

  return shadcn.ThemeData(
    radius: 0.6,
    colorScheme: shadcn.ColorScheme(
      brightness: isDark ? material.Brightness.dark : material.Brightness.light,
      background: palette.bg,
      foreground: palette.ink,
      card: palette.surface,
      cardForeground: palette.ink,
      popover: palette.surface,
      popoverForeground: palette.ink,
      primary: palette.brand,
      primaryForeground: onBrand,
      secondary: palette.brandSoft,
      secondaryForeground: palette.brandStrong,
      muted: palette.surfaceAlt,
      mutedForeground: palette.inkMuted,
      accent: palette.accent,
      accentForeground: onBrand,
      destructive: palette.statusHighFg,
      destructiveForeground: onBrand,
      border: palette.hairline,
      input: palette.hairline,
      ring: palette.brand,
      // Not used by Card/Divider/NumberTicker; filled for completeness since
      // ColorScheme requires them.
      chart1: palette.brand,
      chart2: palette.accent,
      chart3: palette.statusCalmFg,
      chart4: palette.statusMildFg,
      chart5: palette.statusHighFg,
    ),
  );
}
