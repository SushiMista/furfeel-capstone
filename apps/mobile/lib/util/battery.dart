import 'package:flutter/material.dart';

/// Level-aware battery glyph (QA item 14 follow-up): the icon fill tracks the
/// actual charge instead of jumping between "full" and "alert".
IconData batteryIconFor(int percent) => switch (percent) {
      <= 15 => Icons.battery_alert,
      <= 30 => Icons.battery_2_bar,
      <= 45 => Icons.battery_3_bar,
      <= 60 => Icons.battery_4_bar,
      <= 75 => Icons.battery_5_bar,
      <= 90 => Icons.battery_6_bar,
      _ => Icons.battery_full,
    };
