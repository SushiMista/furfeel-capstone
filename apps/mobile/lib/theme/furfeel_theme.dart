import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'furfeel_tokens.dart';

/// App-wide theme derived from the shared design tokens (docs/19 Design Guide):
/// blue + white brand, Material 3, Inter — approachable and reassuring on the
/// owner app (Design 3) while sharing the clinical dashboard's palette.
///
/// ADDED: dark theme. [dark] flips FurFeelTokens.isDark *before* any token is
/// read, so both the Material theme and every widget that reads tokens directly
/// resolve against the same palette. The app root passes exactly one theme to
/// MaterialApp and rebuilds the tree when the setting (or OS brightness) flips.
ThemeData buildFurFeelTheme({bool dark = false}) {
  FurFeelTokens.isDark = dark;

  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FurFeelTokens.brand,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: FurFeelTokens.brand,
      // In dark mode the button blue is lifted, so dark ink text keeps contrast.
      onPrimary: dark ? FurFeelTokens.bg : FurFeelTokens.surface,
      secondary: FurFeelTokens.accent,
      surface: FurFeelTokens.surface,
      onSurface: FurFeelTokens.ink,
      error: FurFeelTokens.statusHighFg,
    ),
    scaffoldBackgroundColor: FurFeelTokens.bg,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: FurFeelTokens.ink,
    displayColor: FurFeelTokens.ink,
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
        color: FurFeelTokens.inkMuted,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: FurFeelTokens.typeCaptionSize,
        color: FurFeelTokens.inkMuted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: FurFeelTokens.bg,
      foregroundColor: FurFeelTokens.brandInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: FurFeelTokens.typeH2Size,
        fontWeight: FontWeight.w800,
        color: FurFeelTokens.brandInk,
      ),
    ),
    cardTheme: CardThemeData(
      color: FurFeelTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(FurFeelTokens.radiusLg)),
        side: BorderSide(color: FurFeelTokens.hairline),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FurFeelTokens.brand,
        foregroundColor: dark ? FurFeelTokens.bg : FurFeelTokens.surface,
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
      fillColor: FurFeelTokens.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FurFeelTokens.space4,
        vertical: FurFeelTokens.space3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: FurFeelTokens.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: FurFeelTokens.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FurFeelTokens.radiusSm),
        borderSide: BorderSide(color: FurFeelTokens.brand, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: FurFeelTokens.surface,
      indicatorColor: FurFeelTokens.brandSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? FurFeelTokens.brandStrong
              : FurFeelTokens.inkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: FurFeelTokens.typeLabelSize,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? FurFeelTokens.brandStrong
              : FurFeelTokens.inkMuted,
        ),
      ),
    ),
    dividerColor: FurFeelTokens.hairline,
  );
}
