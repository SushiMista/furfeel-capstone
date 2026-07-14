// GENERATED from packages/shared/design_tokens.json — do not edit by hand.
// Regenerate with: node packages/shared/scripts/generate_design_tokens.mjs

import 'package:flutter/material.dart';

// ADDED: dark theme — colors resolve through FurFeelTokens.isDark, which the
// app root sets from user_settings.theme (+ platform brightness) before each
// build. The full-tree rebuild on theme change keeps every widget in sync.
// ponytail: static flag + getters over a ThemeExtension refactor; migrate if
// per-subtree theming is ever needed.
class _Palette {
  const _Palette({
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
    required this.warm,
    required this.warmSoft,
    required this.statusCalmFg,
    required this.statusCalmBg,
    required this.statusMildFg,
    required this.statusMildBg,
    required this.statusModerateFg,
    required this.statusModerateBg,
    required this.statusHighFg,
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
  final Color warm;
  final Color warmSoft;
  final Color statusCalmFg;
  final Color statusCalmBg;
  final Color statusMildFg;
  final Color statusMildBg;
  final Color statusModerateFg;
  final Color statusModerateBg;
  final Color statusHighFg;
  final Color statusHighBg;
  final Color statusHighOwner;
}

const _light = _Palette(
  bg: Color(0xFFF7F9FC),
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF1F5F9),
  ink: Color(0xFF0F172A),
  inkMuted: Color(0xFF64748B),
  hairline: Color(0xFFE2E8F0),
  brand: Color(0xFF2563EB),
  brandStrong: Color(0xFF1D4ED8),
  brandInk: Color(0xFF1E3A8A),
  brandSoft: Color(0xFFEAF1FE),
  accent: Color(0xFF14B8A6),
  warm: Color(0xFFF59E0B),
  warmSoft: Color(0xFFFEF3E2),
  statusCalmFg: Color(0xFF0F9D8C),
  statusCalmBg: Color(0xFFE6F6F3),
  statusMildFg: Color(0xFFCA8A04),
  statusMildBg: Color(0xFFFBF3D6),
  statusModerateFg: Color(0xFFEA7317),
  statusModerateBg: Color(0xFFFCEBD9),
  statusHighFg: Color(0xFFDC2626),
  statusHighBg: Color(0xFFFBE4E2),
  statusHighOwner: Color(0xFFE5533D),
);

const _dark = _Palette(
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
  warm: Color(0xFFF5B04A),
  warmSoft: Color(0xFF33270F),
  statusCalmFg: Color(0xFF3BC9B4),
  statusCalmBg: Color(0xFF0D2B27),
  statusMildFg: Color(0xFFE3B93B),
  statusMildBg: Color(0xFF2C2409),
  statusModerateFg: Color(0xFFF0914B),
  statusModerateBg: Color(0xFF33200D),
  statusHighFg: Color(0xFFF07364),
  statusHighBg: Color(0xFF391411),
  statusHighOwner: Color(0xFFF08A7B),
);

/// FurFeel design tokens (docs/19 Design Guide — blue + white).
abstract final class FurFeelTokens {
  /// Set by the app root before building; see furfeel_theme.dart.
  static bool isDark = false;
  static _Palette get _p => isDark ? _dark : _light;

  // Color — resolved against the active theme (word + dot always, never color alone)
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get ink => _p.ink;
  static Color get inkMuted => _p.inkMuted;
  static Color get hairline => _p.hairline;
  static Color get brand => _p.brand;
  static Color get brandStrong => _p.brandStrong;
  static Color get brandInk => _p.brandInk;
  static Color get brandSoft => _p.brandSoft;
  static Color get accent => _p.accent;
  static Color get warm => _p.warm;
  static Color get warmSoft => _p.warmSoft;
  static Color get statusCalmFg => _p.statusCalmFg;
  static Color get statusCalmBg => _p.statusCalmBg;
  static Color get statusMildFg => _p.statusMildFg;
  static Color get statusMildBg => _p.statusMildBg;
  static Color get statusModerateFg => _p.statusModerateFg;
  static Color get statusModerateBg => _p.statusModerateBg;
  static Color get statusHighFg => _p.statusHighFg;
  static Color get statusHighBg => _p.statusHighBg;
  static Color get statusHighOwner => _p.statusHighOwner;

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
