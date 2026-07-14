/// Human timestamps ("just now", "5 min ago", "today at 08:12") — reassuring
/// owner-app tone (docs/19 Design 3) instead of raw ISO strings.
String friendlyTimestamp(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  if (now.year == time.year && now.month == time.month && now.day == time.day) {
    return 'today at $hh:$mm';
  }
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} $hh:$mm';
}
