import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'furfeel_tokens.dart';

/// App-wide theme derived from the shared design tokens (docs/19 Design Guide):
/// blue + white brand, Material 3, Inter — approachable and reassuring on the
/// owner app (Design 3) while sharing the clinical dashboard's palette.
///
/// ADDED: the palette rides on [ThemeData.extensions] as [FurFeelPalette], so
/// widgets resolve colors through `context.ff` and the app root can hand
/// MaterialApp a light + dark theme with themeMode doing the switching — no
/// global mutable state, per-subtree theming possible.
ThemeData buildFurFeelTheme({bool dark = false}) {
  final p = dark ? FurFeelPalette.dark : FurFeelPalette.light;

  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.brand,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: p.brand,
      // In dark mode the button blue is lifted, so dark ink text keeps contrast.
      onPrimary: dark ? p.bg : p.surface,
      secondary: p.accent,
      surface: p.surface,
      onSurface: p.ink,
      error: p.statusHighFg,
    ),
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: p.ink,
    displayColor: p.ink,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      displaySmall: textTheme.displaySmall?.copyWith(
        fontSize: FurFeelTokens.typeDisplaySize,
        fontWeight: FurFeelTokens.typeDisplayWeight,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: FurFeelTokens.typeH1Size,
        fontWeight: FurFeelTokens.typeH1Weight,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontSize: FurFeelTokens.typeH2Size,
        fontWeight: FurFeelTokens.typeH2Weight,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: FurFeelTokens.typeH3Size,
        fontWeight: FurFeelTokens.typeH3Weight,
      ),
      // Mobile bumps body to 16 for readability (docs/19 §3).
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: FurFeelTokens.typeBodyMobileSize,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        fontSize: FurFeelTokens.typeLabelSize,
        fontWeight: FurFeelTokens.typeLabelWeight,
        letterSpacing: FurFeelTokens.labelLetterSpacing,
        color: p.inkMuted,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: FurFeelTokens.typeCaptionSize,
        color: p.inkMuted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.brandInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: FurFeelTokens.typeH2Size,
        fontWeight: FontWeight.w800,
        color: p.brandInk,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(FurFeelTokens.radiusLg)),
        side: BorderSide(color: p.hairline),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.brand,
        foregroundColor: dark ? p.bg : p.surface,
        minimumSize: const Size.fromHeight(FurFeelTokens.touchTargetMin),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(
          fontSize: FurFeelTokens.typeBodyMobileSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: p.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: p.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: p.brand, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.brandSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.brandStrong : p.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: FurFeelTokens.typeLabelSize,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? p.brandStrong : p.inkMuted,
        ),
      ),
    ),
    dividerColor: p.hairline,
  );
}
