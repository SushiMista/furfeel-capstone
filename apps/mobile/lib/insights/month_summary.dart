import '../models/models.dart';
import 'owner_moments.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String monthName(DateTime month) => _months[month.month - 1];

/// Readings this many days in before the page speaks about patterns.
const _enoughDays = 7;

/// One word for a day: calm when it was mostly calm, otherwise its most common
/// non-calm level, the higher one on a tie. Null when there's no data.
StressLevel? dayLevel(DailyStressSummary day) {
  if (day.total == 0) return null;
  if ((day.calmShare ?? 0) >= mostlyCalmShare) return StressLevel.calm;
  if (day.high >= day.moderate && day.high >= day.mild && day.high > 0) {
    return StressLevel.high;
  }
  if (day.moderate >= day.mild && day.moderate > 0) return StressLevel.moderate;
  return day.mild > 0 ? StressLevel.mild : StressLevel.calm;
}

String dayWord(StressLevel? level) => switch (level) {
      null => 'No readings this day',
      StressLevel.calm => 'A calm day',
      StressLevel.mild => 'A mild day',
      StressLevel.moderate => 'A moderate day',
      StressLevel.high => 'A high-stress day',
    };

/// Headline and one supporting sentence for a month of the Trends page.
/// Observational only: it reports what the data showed, never why.
({String headline, String lede}) monthSummary({
  required String dogName,
  required DateTime month,
  required List<DailyStressSummary> days,
  required int alertCount,
  required int calmRun,
  required DateTime now,
  bool hasEarlierData = false,
}) {
  final measured = days.where((d) => d.total > 0).toList();
  final calmDays =
      measured.where((d) => dayLevel(d) == StressLevel.calm).length;
  final name = monthName(month);
  final isCurrent = month.year == now.year && month.month == now.month;
  final dayCount = '${measured.length} ${measured.length == 1 ? 'day' : 'days'}';

  final alerts = '$alertCount ${alertCount == 1 ? 'alert' : 'alerts'}';
  final calmCount = '$calmDays calm ${calmDays == 1 ? 'day' : 'days'}';

  // Early in a month, a dog with history isn't a new dog.
  if (isCurrent && hasEarlierData && measured.length < _enoughDays) {
    return (
      headline: '$name so far',
      lede: measured.isEmpty
          ? 'No readings yet this month.'
          : '$calmCount and $alerts so far.',
    );
  }

  if (measured.isEmpty) {
    return isCurrent
        ? (
            headline: 'Getting to know $dogName',
            lede: 'Trends appear after a day or two of wearing the harness.',
          )
        : (
            headline: 'No readings in $name',
            lede: 'The harness sent no data this month.',
          );
  }
  if (measured.length < _enoughDays) {
    return isCurrent
        ? (
            headline: 'Getting to know $dogName',
            lede: '$dayCount so far. Patterns start showing after about a week.',
          )
        : (
            headline: 'Only $dayCount of readings in $name',
            lede: 'Not enough to say how the month went.',
          );
  }

  final calmShare = calmDays / measured.length;
  final mood = calmShare >= mostlyCalmShare
      ? 'calm'
      : calmShare >= 0.4
          ? 'mixed'
          : 'harder';
  final run = isCurrent && calmRun >= 2
      ? ', with $calmRun calm days in a row so far'
      : '';
  return (
    headline: 'A $mood $name for $dogName',
    lede: '$calmCount and $alerts$run.',
  );
}

/// The hour that stood out most, for the day panel. Null on a calm or empty day.
int? hardestHour(List<StressLevel?> hours) {
  int? worst;
  for (final (hour, level) in hours.indexed) {
    if (level == null || level == StressLevel.calm) continue;
    if (worst == null || level.index > hours[worst]!.index) worst = hour;
  }
  return worst;
}
