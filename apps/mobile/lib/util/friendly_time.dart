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

/// Plain 12-hour clock time for live status labels, e.g. "3:42 PM".
String clockTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}
