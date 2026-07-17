/// CSV + PDF export builders for the detailed log (QA item 13). Pure functions
/// over readings so they unit-test without any platform channel.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';

String _csvCell(Object? v) => v == null ? '' : v.toString();

String _stamp(DateTime t) => t.toIso8601String();

/// RFC-4180-enough CSV of raw readings, oldest-first. Temperature stays in °C
/// (a data export shouldn't depend on a display preference); the app's PDF
/// report is the friendly, unit-aware artifact.
String buildReadingsCsv(List<TelemetryReading> readings) {
  final buffer = StringBuffer(
    'captured_at,heart_rate_bpm,respiratory_rate_bpm,body_temperature_c,'
    'motion_activity,posture,ambient_temperature_c,humidity_percent,battery_percent\n',
  );
  for (final r in readings) {
    buffer.writeln([
      _stamp(r.capturedAt),
      _csvCell(r.heartRateBpm),
      _csvCell(r.respiratoryRateBpm),
      _csvCell(r.bodyTemperatureC),
      _csvCell(r.motionActivity),
      _csvCell(r.posture),
      _csvCell(r.ambientTemperatureC),
      _csvCell(r.humidityPercent),
      _csvCell(r.batteryPercent),
    ].join(','));
  }
  return buffer.toString();
}

/// Min/avg/max over the non-null values of one vital.
({double min, double avg, double max})? vitalSummary(
  List<TelemetryReading> readings,
  double? Function(TelemetryReading) pick,
) {
  final values = readings.map(pick).whereType<double>().toList();
  if (values.isEmpty) return null;
  var min = values.first, max = values.first, sum = 0.0;
  for (final v in values) {
    if (v < min) min = v;
    if (v > max) max = v;
    sum += v;
  }
  return (min: min, avg: sum / values.length, max: max);
}

String _fmtRange(({double min, double avg, double max})? s, {int decimals = 0}) =>
    s == null
        ? '—'
        : '${s.min.toStringAsFixed(decimals)} / ${s.avg.toStringAsFixed(decimals)} / '
            '${s.max.toStringAsFixed(decimals)}';

/// Shareable PDF health report: dog + range header, per-vital min/avg/max,
/// stress mix, and the decision-support disclaimer. Deliberately simple —
/// something an owner can hand a vet, not a clinical document.
Future<Uint8List> buildHealthReportPdf({
  required Dog dog,
  required DateTime from,
  required DateTime to,
  required List<TelemetryReading> readings,
  required List<StressClassification> classifications,
}) async {
  final doc = pw.Document();

  final mix = <StressLevel, int>{};
  for (final c in classifications) {
    mix[c.stressLevel] = (mix[c.stressLevel] ?? 0) + 1;
  }
  final mixTotal = classifications.length;

  String day(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  pw.TableRow row(String label, String value) => pw.TableRow(children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ]);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('FurFeel health report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('${dog.name}${dog.breed == null ? '' : ' · ${dog.breed}'}'),
          pw.Text('${day(from)} to ${day(to)} · ${readings.length} readings'),
          pw.SizedBox(height: 16),
          pw.Text('Vitals (min / average / max)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              row('Heart rate (bpm)',
                  _fmtRange(vitalSummary(readings, (r) => r.heartRateBpm?.toDouble()))),
              row(
                  'Breathing (breaths/min)',
                  _fmtRange(
                      vitalSummary(readings, (r) => r.respiratoryRateBpm?.toDouble()))),
              row('Body temperature (°C)',
                  _fmtRange(vitalSummary(readings, (r) => r.bodyTemperatureC), decimals: 1)),
              row('Motion (0–1)',
                  _fmtRange(vitalSummary(readings, (r) => r.motionActivity), decimals: 2)),
              row('Ambient temperature (°C)',
                  _fmtRange(vitalSummary(readings, (r) => r.ambientTemperatureC), decimals: 1)),
              row('Humidity (%)',
                  _fmtRange(vitalSummary(readings, (r) => r.humidityPercent), decimals: 0)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Stress levels in this period',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (mixTotal == 0)
            pw.Text('No stress classifications recorded in this period.',
                style: const pw.TextStyle(fontSize: 11))
          else
            pw.Table(
              columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                for (final level in StressLevel.values)
                  row(
                    level.name[0].toUpperCase() + level.name.substring(1),
                    '${mix[level] ?? 0} of $mixTotal '
                    '(${(100 * (mix[level] ?? 0) / mixTotal).toStringAsFixed(0)}%)',
                  ),
              ],
            ),
          pw.Spacer(),
          pw.Text(
            'Generated by FurFeel. These readings describe what the harness '
            'observed — they support conversations with your veterinary team '
            'and are not a medical assessment.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
