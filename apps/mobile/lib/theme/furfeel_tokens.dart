// GENERATED from packages/shared/design_tokens.json — do not edit by hand.
// Regenerate with: node packages/shared/scripts/generate_design_tokens.mjs

import 'package:flutter/material.dart';

/// FurFeel colors as a Material [ThemeExtension] (docs/19 Design Guide).
/// Registered on [ThemeData.extensions] by buildFurFeelTheme; read it with
/// `context.ff` (word + dot always, never color alone).
class FurFeelPalette extends ThemeExtension<FurFeelPalette> {
  const FurFeelPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.hairline,
    required this.brand,
    required this.brandStrong,
    required this.brandInk,
    required this.brandSoft,
    required this.accent,
    required this.accentStrong,
    required this.accentInk,
    required this.accentSoft,
    required this.warm,
    required this.warmSoft,
    required this.tintBlue,
    required this.tintTeal,
    required this.tintPeriwinkle,
    required this.tintSlate,
    required this.vitalHeart,
    required this.vitalBreathing,
    required this.vitalActivity,
    required this.statusCalmFg,
    required this.statusCalmMid,
    required this.statusCalmBg,
    required this.statusMildFg,
    required this.statusMildMid,
    required this.statusMildBg,
    required this.statusModerateFg,
    required this.statusModerateMid,
    required this.statusModerateBg,
    required this.statusHighFg,
    required this.statusHighMid,
    required this.statusHighBg,
    required this.statusHighOwner,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color hairline;
  final Color brand;
  final Color brandStrong;
  final Color brandInk;
  final Color brandSoft;
  final Color accent;
  final Color accentStrong;
  final Color accentInk;
  final Color accentSoft;
  final Color warm;
  final Color warmSoft;
  final Color tintBlue;
  final Color tintTeal;
  final Color tintPeriwinkle;
  final Color tintSlate;
  final Color vitalHeart;
  final Color vitalBreathing;
  final Color vitalActivity;
  final Color statusCalmFg;
  final Color statusCalmMid;
  final Color statusCalmBg;
  final Color statusMildFg;
  final Color statusMildMid;
  final Color statusMildBg;
  final Color statusModerateFg;
  final Color statusModerateMid;
  final Color statusModerateBg;
  final Color statusHighFg;
  final Color statusHighMid;
  final Color statusHighBg;
  final Color statusHighOwner;

  static const light = FurFeelPalette(
    bg: Color(0xFFF7F9FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F9),
    ink: Color(0xFF0F172A),
    inkMuted: Color(0xFF64748B),
    hairline: Color(0xFFE2E8F0),
    brand: Color(0xFF2F56A7),
    brandStrong: Color(0xFF1D4ED8),
    brandInk: Color(0xFF1E3A8A),
    brandSoft: Color(0xFFEAF1FE),
    accent: Color(0xFF14B8A6),
    accentStrong: Color(0xFF0D9488),
    accentInk: Color(0xFF0F766E),
    accentSoft: Color(0xFFE3F4F1),
    warm: Color(0xFF9A6407),
    warmSoft: Color(0xFFFEF3E2),
    tintBlue: Color(0xFFE7EEFD),
    tintTeal: Color(0xFFE1F3F0),
    tintPeriwinkle: Color(0xFFEAEAFB),
    tintSlate: Color(0xFFEDF1F6),
    vitalHeart: Color(0xFFE0466F),
    vitalBreathing: Color(0xFF0E9E90),
    vitalActivity: Color(0xFF6A61DE),
    statusCalmFg: Color(0xFF0C7C6F),
    statusCalmMid: Color(0xFF2CA089),
    statusCalmBg: Color(0xFFE6F6F3),
    statusMildFg: Color(0xFF956603),
    statusMildMid: Color(0xFFBE8927),
    statusMildBg: Color(0xFFFBF3D6),
    statusModerateFg: Color(0xFFA85311),
    statusModerateMid: Color(0xFFD9773F),
    statusModerateBg: Color(0xFFFCEBD9),
    statusHighFg: Color(0xFFCA2323),
    statusHighMid: Color(0xFFE05A4E),
    statusHighBg: Color(0xFFFBE4E2),
    statusHighOwner: Color(0xFFB74231),
  );

  static const dark = FurFeelPalette(
    bg: Color(0xFF0B1220),
    surface: Color(0xFF111B2E),
    surfaceAlt: Color(0xFF18243B),
    ink: Color(0xFFE6EDF8),
    inkMuted: Color(0xFF94A7C4),
    hairline: Color(0xFF223250),
    brand: Color(0xFF5B8DEF),
    brandStrong: Color(0xFF7DA4F3),
    brandInk: Color(0xFFBFD2F8),
    brandSoft: Color(0xFF17294B),
    accent: Color(0xFF2DD4BF),
    accentStrong: Color(0xFF5EEAD4),
    accentInk: Color(0xFF99F6E4),
    accentSoft: Color(0xFF10312D),
    warm: Color(0xFFF5B04A),
    warmSoft: Color(0xFF33270F),
    tintBlue: Color(0xFF1A2540),
    tintTeal: Color(0xFF12302C),
    tintPeriwinkle: Color(0xFF22213F),
    tintSlate: Color(0xFF1B2433),
    vitalHeart: Color(0xFFF386A5),
    vitalBreathing: Color(0xFF3CC6B6),
    vitalActivity: Color(0xFF9A93F0),
    statusCalmFg: Color(0xFF3BC9B4),
    statusCalmMid: Color(0xFF34BFA8),
    statusCalmBg: Color(0xFF0D2B27),
    statusMildFg: Color(0xFFE3B93B),
    statusMildMid: Color(0xFFD2A63F),
    statusMildBg: Color(0xFF2C2409),
    statusModerateFg: Color(0xFFF0914B),
    statusModerateMid: Color(0xFFE08A4F),
    statusModerateBg: Color(0xFF33200D),
    statusHighFg: Color(0xFFF07364),
    statusHighMid: Color(0xFFE0685C),
    statusHighBg: Color(0xFF391411),
    statusHighOwner: Color(0xFFF08A7B),
  );

  @override
  FurFeelPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? hairline,
    Color? brand,
    Color? brandStrong,
    Color? brandInk,
    Color? brandSoft,
    Color? accent,
    Color? accentStrong,
    Color? accentInk,
    Color? accentSoft,
    Color? warm,
    Color? warmSoft,
    Color? tintBlue,
    Color? tintTeal,
    Color? tintPeriwinkle,
    Color? tintSlate,
    Color? vitalHeart,
    Color? vitalBreathing,
    Color? vitalActivity,
    Color? statusCalmFg,
    Color? statusCalmMid,
    Color? statusCalmBg,
    Color? statusMildFg,
    Color? statusMildMid,
    Color? statusMildBg,
    Color? statusModerateFg,
    Color? statusModerateMid,
    Color? statusModerateBg,
    Color? statusHighFg,
    Color? statusHighMid,
    Color? statusHighBg,
    Color? statusHighOwner,
  }) =>
      FurFeelPalette(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        hairline: hairline ?? this.hairline,
        brand: brand ?? this.brand,
        brandStrong: brandStrong ?? this.brandStrong,
        brandInk: brandInk ?? this.brandInk,
        brandSoft: brandSoft ?? this.brandSoft,
        accent: accent ?? this.accent,
        accentStrong: accentStrong ?? this.accentStrong,
        accentInk: accentInk ?? this.accentInk,
        accentSoft: accentSoft ?? this.accentSoft,
        warm: warm ?? this.warm,
        warmSoft: warmSoft ?? this.warmSoft,
        tintBlue: tintBlue ?? this.tintBlue,
        tintTeal: tintTeal ?? this.tintTeal,
        tintPeriwinkle: tintPeriwinkle ?? this.tintPeriwinkle,
        tintSlate: tintSlate ?? this.tintSlate,
        vitalHeart: vitalHeart ?? this.vitalHeart,
        vitalBreathing: vitalBreathing ?? this.vitalBreathing,
        vitalActivity: vitalActivity ?? this.vitalActivity,
        statusCalmFg: statusCalmFg ?? this.statusCalmFg,
        statusCalmMid: statusCalmMid ?? this.statusCalmMid,
        statusCalmBg: statusCalmBg ?? this.statusCalmBg,
        statusMildFg: statusMildFg ?? this.statusMildFg,
        statusMildMid: statusMildMid ?? this.statusMildMid,
        statusMildBg: statusMildBg ?? this.statusMildBg,
        statusModerateFg: statusModerateFg ?? this.statusModerateFg,
        statusModerateMid: statusModerateMid ?? this.statusModerateMid,
        statusModerateBg: statusModerateBg ?? this.statusModerateBg,
        statusHighFg: statusHighFg ?? this.statusHighFg,
        statusHighMid: statusHighMid ?? this.statusHighMid,
        statusHighBg: statusHighBg ?? this.statusHighBg,
        statusHighOwner: statusHighOwner ?? this.statusHighOwner,
      );

  @override
  FurFeelPalette lerp(FurFeelPalette? other, double t) {
    if (other == null) return this;
    return FurFeelPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      warmSoft: Color.lerp(warmSoft, other.warmSoft, t)!,
      tintBlue: Color.lerp(tintBlue, other.tintBlue, t)!,
      tintTeal: Color.lerp(tintTeal, other.tintTeal, t)!,
      tintPeriwinkle: Color.lerp(tintPeriwinkle, other.tintPeriwinkle, t)!,
      tintSlate: Color.lerp(tintSlate, other.tintSlate, t)!,
      vitalHeart: Color.lerp(vitalHeart, other.vitalHeart, t)!,
      vitalBreathing: Color.lerp(vitalBreathing, other.vitalBreathing, t)!,
      vitalActivity: Color.lerp(vitalActivity, other.vitalActivity, t)!,
      statusCalmFg: Color.lerp(statusCalmFg, other.statusCalmFg, t)!,
      statusCalmMid: Color.lerp(statusCalmMid, other.statusCalmMid, t)!,
      statusCalmBg: Color.lerp(statusCalmBg, other.statusCalmBg, t)!,
      statusMildFg: Color.lerp(statusMildFg, other.statusMildFg, t)!,
      statusMildMid: Color.lerp(statusMildMid, other.statusMildMid, t)!,
      statusMildBg: Color.lerp(statusMildBg, other.statusMildBg, t)!,
      statusModerateFg: Color.lerp(statusModerateFg, other.statusModerateFg, t)!,
      statusModerateMid: Color.lerp(statusModerateMid, other.statusModerateMid, t)!,
      statusModerateBg: Color.lerp(statusModerateBg, other.statusModerateBg, t)!,
      statusHighFg: Color.lerp(statusHighFg, other.statusHighFg, t)!,
      statusHighMid: Color.lerp(statusHighMid, other.statusHighMid, t)!,
      statusHighBg: Color.lerp(statusHighBg, other.statusHighBg, t)!,
      statusHighOwner: Color.lerp(statusHighOwner, other.statusHighOwner, t)!,
    );
  }
}

/// `context.ff.brand` — the palette for the ambient theme. Falls back to
/// light when no FurFeel theme is installed (e.g. bare-widget tests).
extension FurFeelPaletteContext on BuildContext {
  FurFeelPalette get ff =>
      Theme.of(this).extension<FurFeelPalette>() ?? FurFeelPalette.light;
}

/// FurFeel non-color design tokens (docs/19 Design Guide).
abstract final class FurFeelTokens {
  // Radius (mobile set — rounder and friendlier than the dashboard)
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusPill = 999;

  // Spacing scale (4 / 8 / 12 / 16 / 24 / 32 / 48)
  static const List<double> spacing = [4, 8, 12, 16, 24, 32, 48];
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;

  // Elevation: soft and low — hairline borders + subtle shadow
  static const List<BoxShadow> shadowCard = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0D0F172A), offset: Offset(0, 4), blurRadius: 12),
  ];

  // Typography scale
  static const double typeDisplaySize = 30;
  static const FontWeight typeDisplayWeight = FontWeight.w700;
  static const double typeH1Size = 24;
  static const FontWeight typeH1Weight = FontWeight.w700;
  static const double typeH2Size = 20;
  static const FontWeight typeH2Weight = FontWeight.w600;
  static const double typeH3Size = 16;
  static const FontWeight typeH3Weight = FontWeight.w600;
  static const double typeBodySize = 15;
  static const FontWeight typeBodyWeight = FontWeight.w400;
  static const double typeBodyMobileSize = 16;
  static const FontWeight typeBodyMobileWeight = FontWeight.w400;
  static const double typeLabelSize = 12;
  static const FontWeight typeLabelWeight = FontWeight.w600;
  static const double typeCaptionSize = 12;
  static const FontWeight typeCaptionWeight = FontWeight.w400;
  static const double typeVitalNumberSize = 30;
  static const FontWeight typeVitalNumberWeight = FontWeight.w700;
  static const double labelLetterSpacing = 0.4;

  // Motion: calm and quick, ease-out
  static const Duration motionFast = Duration(milliseconds: 150);
  static const Duration motionSlow = Duration(milliseconds: 250);

  static const double touchTargetMin = 44;
}
