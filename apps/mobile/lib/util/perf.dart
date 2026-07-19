import 'package:flutter/foundation.dart';

/// ADDED (ISO 25010 performance-efficiency evidence, docs/20): in-session
/// response-time samples with p50/p95 in the debug log. Read the `[perf]`
/// lines while driving the app — no backend, no third-party telemetry
/// (privacy stance, docs/12).
final Map<String, List<int>> _samples = {};

/// Nearest-rank percentile; expects a sorted ascending list.
int percentileMs(List<int> sortedMs, int p) {
  if (sortedMs.isEmpty) return 0;
  final rank = (p / 100 * sortedMs.length).ceil();
  return sortedMs[rank.clamp(1, sortedMs.length) - 1];
}

Future<T> timed<T>(String metric, Future<T> Function() fn) async {
  final stopwatch = Stopwatch()..start();
  try {
    return await fn();
  } finally {
    stopwatch.stop();
    final list = _samples.putIfAbsent(metric, () => []);
    list.add(stopwatch.elapsedMilliseconds);
    final sorted = [...list]..sort();
    debugPrint('[perf] $metric ${stopwatch.elapsedMilliseconds}ms '
        '(session n=${sorted.length} p50=${percentileMs(sorted, 50)}ms '
        'p95=${percentileMs(sorted, 95)}ms)');
  }
}
