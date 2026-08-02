import 'package:flutter/material.dart';

import '../theme/furfeel_tokens.dart';

/// A few small bars showing where a value has recently been.
///
/// Bars, not a line: at this size a stroke reads as noise, and a 5–7px bar
/// survives being drawn on a half-width card in a way a 1px line does not.
///
/// Renders nothing below [minPoints] readings. A trend drawn from a single
/// point is not a trend, and an empty chart frame implies data that isn't
/// there — worse than no chart at all.
class MicroSparkline extends StatelessWidget {
  const MicroSparkline({
    super.key,
    required this.series,
    required this.color,
    this.height = 40,
    this.barWidth = 7,
    this.gap = 5,
    this.minPoints = 2,
    this.trackColor,
    this.labels,
  });

  /// Readings, oldest first. A `null` entry is an unreported column — it draws
  /// the light track only (never a value bar), so a gap in a weekly view reads
  /// as "no data that day", not as a low reading.
  final List<double?> series;

  /// Fill colour. Pass a status `mid` stop or the brand — never a text stop
  /// (docs/19: chart fills answer to 3:1, text to 4.5:1).
  final Color color;

  final double height;
  final double barWidth;
  final double gap;
  final int minPoints;

  /// When set, each bar sits in a full-height light capsule (the board's
  /// chart look — docs/22). An unreported column still shows its track, so a
  /// gap never reads as missing data. Pass `brandSoft` for brand bars, the
  /// status `soft` stop for status bars. Null keeps the bare-bar look.
  final Color? trackColor;

  /// Optional caption under each column, e.g. day initials `M T W T F S S`.
  /// Must match [series] length; ignored otherwise.
  final List<String>? labels;

  /// Floor so a zero reading still shows as a bar rather than disappearing —
  /// a missing bar reads as missing data, which is a different claim.
  static const double _floor = 4;

  @override
  Widget build(BuildContext context) {
    // Count real readings. A track-backed weekly view still renders its slots
    // when data is sparse (the empty tracks are the point); a bare inline trend
    // hides rather than imply a trend from a single point.
    final present = series.whereType<double>().length;
    if (present < minPoints && trackColor == null) {
      return const SizedBox.shrink();
    }

    // A flat series — every reading identical, including all-zero — would
    // divide by zero on normalisation. It falls back to the floor and renders
    // as an honest flat line.
    final max = series.fold<double>(0, (a, b) => (b ?? 0) > a ? b! : a);
    final pill = BorderRadius.circular(FurFeelTokens.radiusPill);

    Widget bar(int i) {
      final v = series[i];
      final track = trackColor;
      // Unreported day: the track alone (or nothing, if this view has no track).
      if (v == null) {
        if (track == null) return SizedBox(width: barWidth);
        return Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: pill),
        );
      }
      final value = Container(
        width: barWidth,
        height: max <= 0 ? _floor : _floor + (v / max) * (height - _floor),
        decoration: BoxDecoration(color: color, borderRadius: pill),
      );
      if (track == null) return value;
      // Value capsule sits in a full-height light track, bottom-aligned — the
      // board's chart look, and the track keeps unreported columns from
      // reading as a gap.
      return SizedBox(
        width: barWidth,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              decoration: BoxDecoration(color: track, borderRadius: pill),
            ),
            value,
          ],
        ),
      );
    }

    final bars = SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < series.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            bar(i),
          ],
        ],
      ),
    );

    final captions = labels;
    if (captions == null || captions.length != series.length) return bars;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bars,
        SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < captions.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(
                width: barWidth,
                child: Text(
                  captions[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: FurFeelTokens.typeCaptionSize,
                    color: context.ff.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
