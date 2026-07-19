/// CSV + PDF export builders for the detailed log (QA item 13). Pure functions
/// over readings so they unit-test without any platform channel.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../theme/furfeel_tokens.dart';

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
    buffer.writeln(
      [
        _stamp(r.capturedAt),
        _csvCell(r.heartRateBpm),
        _csvCell(r.respiratoryRateBpm),
        _csvCell(r.bodyTemperatureC),
        _csvCell(r.motionActivity),
        _csvCell(r.posture),
        _csvCell(r.ambientTemperatureC),
        _csvCell(r.humidityPercent),
        _csvCell(r.batteryPercent),
      ].join(','),
    );
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

// Brand palette from the generated tokens (docs/19), light set: the PDF is a
// printed artifact, so light values are the right ones regardless of the
// viewer's app theme. Derived, not mirrored — token changes flow in.
final _brand = PdfColor.fromInt(FurFeelPalette.light.brand.toARGB32());
final _brandInk = PdfColor.fromInt(FurFeelPalette.light.brandInk.toARGB32());
final _brandSoft = PdfColor.fromInt(FurFeelPalette.light.brandSoft.toARGB32());

final _levelColors = {
  StressLevel.calm: PdfColor.fromInt(
    FurFeelPalette.light.statusCalmFg.toARGB32(),
  ),
  StressLevel.mild: PdfColor.fromInt(
    FurFeelPalette.light.statusMildFg.toARGB32(),
  ),
  StressLevel.moderate: PdfColor.fromInt(
    FurFeelPalette.light.statusModerateFg.toARGB32(),
  ),
  StressLevel.high: PdfColor.fromInt(
    FurFeelPalette.light.statusHighFg.toARGB32(),
  ),
};

String _day(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Section heading with the brand rule under it.
pw.Widget _section(String title) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
  padding: const pw.EdgeInsets.only(bottom: 4),
  decoration: pw.BoxDecoration(
    border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.5)),
  ),
  child: pw.Text(
    title.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: _brandInk,
      letterSpacing: 1.2,
    ),
  ),
);

/// Label/value line inside an info panel; nulls render as a dash so the
/// receiving clinic can see the field was empty, not omitted. ASCII only:
/// the pdf package's built-in Helvetica can't draw en/em dashes.
pw.Widget _field(String label, String? value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 3),
  child: pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
      children: [
        pw.TextSpan(
          text: '$label:  ',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _brandInk,
          ),
        ),
        pw.TextSpan(text: value == null || value.isEmpty ? '-' : value),
      ],
    ),
  ),
);

pw.Widget _infoPanel(String title, List<pw.Widget> fields) => pw.Expanded(
  child: pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _brandSoft,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _brand,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 6),
        ...fields,
      ],
    ),
  ),
);

pw.Widget _cell(String text, {bool header = false, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (header ? _brandInk : PdfColors.grey800),
        ),
      ),
    );

pw.TableRow _headerRow(List<String> cells) => pw.TableRow(
  decoration: pw.BoxDecoration(color: _brandSoft),
  children: [for (final c in cells) _cell(c, header: true)],
);

/// Shareable PDF health record, formatted as a document another veterinary
/// clinic can file: branded masthead, patient/owner/clinic details, vitals,
/// stress distribution, alert history, and the decision-support disclaimer
/// on every page. Owner/clinic/alerts are optional so lighter call sites
/// still export.
Future<Uint8List> buildHealthReportPdf({
  required Dog dog,
  required DateTime from,
  required DateTime to,
  required List<TelemetryReading> readings,
  required List<StressClassification> classifications,
  UserProfile? owner,
  Clinic? clinic,
  List<Alert> alerts = const [],
}) async {
  final doc = pw.Document(
    title: 'FurFeel health record - ${dog.name}',
    producer: 'FurFeel',
  );

  final mix = <StressLevel, int>{};
  for (final c in classifications) {
    mix[c.stressLevel] = (mix[c.stressLevel] ?? 0) + 1;
  }
  final mixTotal = classifications.length;
  final periodAlerts = alerts
      .where((a) => !a.createdAt.isBefore(from) && !a.createdAt.isAfter(to))
      .toList();
  final age = dog.ageYears;

  pw.TableRow vitalRow(
    String vital,
    String unit,
    ({double min, double avg, double max})? s, {
    int decimals = 0,
  }) => pw.TableRow(
    children: [
      _cell(vital),
      _cell(unit),
      _cell(s == null ? '-' : s.min.toStringAsFixed(decimals)),
      _cell(s == null ? '-' : s.avg.toStringAsFixed(decimals)),
      _cell(s == null ? '-' : s.max.toStringAsFixed(decimals)),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Generated by FurFeel. These readings describe what the '
                'harness observed - they support conversations with your '
                'veterinary team and are not a medical assessment.',
                style: const pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
      build: (context) => [
        // ── Masthead ────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: pw.BoxDecoration(
            color: _brand,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FurFeel',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Canine stress monitoring',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'HEALTH RECORD',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.Text(
                    'Issued ${_day(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Monitoring period ${_day(from)} to ${_day(to)} · '
          '${readings.length} readings · $mixTotal stress assessments',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),

        // ── Patient · owner · clinic ────────────────────────────────────
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _infoPanel('Patient', [
              _field('Name', dog.name),
              _field('Breed', dog.breed),
              _field('Sex', dog.sex == null ? null : _cap(dog.sex!)),
              _field(
                'Date of birth',
                dog.birthdate == null
                    ? null
                    : '${dog.birthdate}${age == null ? '' : ' ($age y)'}',
              ),
              _field(
                'Weight',
                dog.weightKg == null ? null : '${dog.weightKg} kg',
              ),
            ]),
            pw.SizedBox(width: 10),
            _infoPanel('Owner', [
              _field('Name', owner?.name),
              _field('Email', owner?.email),
              _field('Phone', owner?.phone),
              _field('Emergency contact', owner?.emergencyContact),
            ]),
            pw.SizedBox(width: 10),
            _infoPanel('Veterinary clinic', [
              if (clinic == null)
                pw.Text(
                  'Home monitoring - no clinic linked.',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey800,
                  ),
                )
              else ...[
                _field('Clinic', clinic.name),
                _field('Address', clinic.address),
              ],
            ]),
          ],
        ),

        // ── Vitals ──────────────────────────────────────────────────────
        _section('Vitals summary'),
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
          },
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: PdfColors.grey300,
              width: 0.5,
            ),
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
          children: [
            _headerRow(['Vital', 'Unit', 'Min', 'Average', 'Max']),
            vitalRow(
              'Heart rate',
              'bpm',
              vitalSummary(readings, (r) => r.heartRateBpm?.toDouble()),
            ),
            vitalRow(
              'Respiratory rate',
              'breaths/min',
              vitalSummary(readings, (r) => r.respiratoryRateBpm?.toDouble()),
            ),
            vitalRow(
              'Body temperature',
              '°C',
              vitalSummary(readings, (r) => r.bodyTemperatureC),
              decimals: 1,
            ),
            vitalRow(
              'Motion activity',
              'index 0-1',
              vitalSummary(readings, (r) => r.motionActivity),
              decimals: 2,
            ),
            vitalRow(
              'Ambient temperature',
              '°C',
              vitalSummary(readings, (r) => r.ambientTemperatureC),
              decimals: 1,
            ),
            vitalRow(
              'Humidity',
              '%',
              vitalSummary(readings, (r) => r.humidityPercent),
            ),
          ],
        ),

        // ── Stress distribution ─────────────────────────────────────────
        _section('Stress level distribution'),
        if (mixTotal == 0)
          pw.Text(
            'No stress classifications recorded in this period.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          )
        else
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(4),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            children: [
              _headerRow(['Level', 'Readings', 'Share', '']),
              for (final level in StressLevel.values)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 8,
                      ),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 8,
                            height: 8,
                            decoration: pw.BoxDecoration(
                              color: _levelColors[level],
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                          pw.SizedBox(width: 5),
                          pw.Text(
                            _cap(level.name),
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _cell('${mix[level] ?? 0}'),
                    _cell(
                      '${(100 * (mix[level] ?? 0) / mixTotal).toStringAsFixed(0)}%',
                    ),
                    // Proportional bar so the mix reads at a glance on paper.
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 7,
                        horizontal: 8,
                      ),
                      child: (mix[level] ?? 0) == 0
                          ? pw.Container(
                              height: 6,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey200,
                                borderRadius: pw.BorderRadius.circular(3),
                              ),
                            )
                          : pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: mix[level]!,
                                  child: pw.Container(
                                    height: 6,
                                    decoration: pw.BoxDecoration(
                                      color: _levelColors[level],
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                                if (mixTotal - mix[level]! > 0)
                                  pw.Expanded(
                                    flex: mixTotal - mix[level]!,
                                    child: pw.Container(
                                      height: 6,
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.grey200,
                                        borderRadius: pw.BorderRadius.circular(
                                          3,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
            ],
          ),

        // ── Alerts ──────────────────────────────────────────────────────
        if (alerts.isNotEmpty) ...[
          _section('Alerts in this period'),
          if (periodAlerts.isEmpty)
            pw.Text(
              'No alerts were raised in this period.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            )
          else
            pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(5),
              },
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
              children: [
                _headerRow(['Date', 'Severity', 'Alert']),
                for (final a in periodAlerts.take(20))
                  pw.TableRow(
                    children: [
                      _cell(_day(a.createdAt)),
                      _cell(
                        _cap(a.severity),
                        color: a.severity == 'critical'
                            ? _levelColors[StressLevel.high]
                            : a.severity == 'warning'
                            ? _levelColors[StressLevel.moderate]
                            : null,
                      ),
                      _cell(a.message),
                    ],
                  ),
              ],
            ),
          if (periodAlerts.length > 20)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Showing the 20 most recent of ${periodAlerts.length} alerts.',
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey600,
                ),
              ),
            ),
        ],
      ],
    ),
  );

  return doc.save();
}
