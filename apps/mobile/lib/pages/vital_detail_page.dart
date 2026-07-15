import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../data/settings_controller.dart';
import '../models/activity_state.dart';
import '../models/models.dart';
import '../theme/furfeel_tokens.dart';
import '../util/friendly_time.dart';
import '../util/motion.dart';
import '../widgets/activity_indicator.dart';

/// ADDED (QA): one screen per vital. The Home grid opens this with the current
/// reading; it shows the typical resting range for the dog (their clinic-set
/// baseline when available, otherwise the general reference the classifier
/// uses) and plain-language owner guidance. Informational only — ranges vary
/// by breed, size, and age; never a diagnosis.
enum VitalKind { heartRate, breathing, temperature, activity }

extension VitalKindInfo on VitalKind {
  String get label => switch (this) {
        VitalKind.heartRate => 'Heart rate',
        VitalKind.breathing => 'Breathing',
        VitalKind.temperature => 'Temperature',
        VitalKind.activity => 'Activity',
      };

  IconData get icon => switch (this) {
        VitalKind.heartRate => Icons.favorite_outline,
        VitalKind.breathing => Icons.air,
        VitalKind.temperature => Icons.thermostat_outlined,
        VitalKind.activity => Icons.directions_run_outlined,
      };
}

class VitalDetailPage extends StatefulWidget {
  const VitalDetailPage({
    super.key,
    required this.repository,
    required this.dog,
    required this.kind,
    this.reading,
  });

  final FurFeelRepository repository;
  final Dog dog;
  final VitalKind kind;
  final TelemetryReading? reading;

  @override
  State<VitalDetailPage> createState() => _VitalDetailPageState();
}

class _VitalDetailPageState extends State<VitalDetailPage> {
  DogBaseline? _baseline;

  @override
  void initState() {
    super.initState();
    widget.repository.fetchBaseline(widget.dog.id).then((b) {
      if (mounted) setState(() => _baseline = b);
    }).catchError((_) {});
  }

  // Owner-friendly reference ranges. Baseline (clinic-set) wins; the general
  // range matches the classifier's provisional global defaults (docs/08 /
  // classifier_config.json) so the app never contradicts its own alerts.
  ({String value, String source}) _typicalRange(SettingsController settings) {
    final b = _baseline;
    switch (widget.kind) {
      case VitalKind.heartRate:
        if (b?.restingHeartRateBpm != null) {
          return (
            value: 'around ${b!.restingHeartRateBpm} bpm at rest',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        return (
          value: '60–120 bpm at rest',
          source: 'general reference for adult dogs',
        );
      case VitalKind.breathing:
        if (b?.restingRespiratoryRateBpm != null) {
          return (
            value: 'around ${b!.restingRespiratoryRateBpm} breaths/min at rest',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        return (
          value: '15–35 breaths/min at rest',
          source: 'general reference for adult dogs',
        );
      case VitalKind.temperature:
        if (b?.normalBodyTemperatureC != null) {
          final v = settings.formatTemperature(b!.normalBodyTemperatureC);
          return (
            value: 'around $v${settings.temperatureUnitLabel}',
            source: 'set by your clinic for ${widget.dog.name}',
          );
        }
        final lo = settings.formatTemperature(37.5);
        final hi = settings.formatTemperature(39.2);
        return (
          value: '$lo–$hi${settings.temperatureUnitLabel}',
          source: 'general reference for adult dogs',
        );
      case VitalKind.activity:
        return (
          value: 'below 0.6 when resting (scale 0–1)',
          source: 'how the harness measures movement',
        );
    }
  }

  String get _whatItMeans => switch (widget.kind) {
        VitalKind.heartRate =>
          'The harness reads your dog\'s pulse continuously. Smaller dogs '
              'naturally run faster than larger ones, and excitement, play, or '
              'heat push it up for a while — that\'s normal. FurFeel looks at '
              'how far it sits above your dog\'s own resting level, and for '
              'how long, before it counts toward stress.',
        VitalKind.breathing =>
          'Breaths per minute, measured at the chest. Panting after play or '
              'in warm weather is expected; fast breathing while resting in a '
              'cool, calm place is what FurFeel watches for.',
        VitalKind.temperature =>
          'Dogs run warmer than people. A little variation through the day '
              'is normal; sustained readings above the typical range count '
              'toward the stress level and can be worth mentioning to your '
              'clinic.',
        VitalKind.activity =>
          'A 0-to-1 movement index from the harness motion sensor — 0 is '
              'still, 1 is constant motion. Restless pacing scores high even '
              'without exercise, which is why it feeds the stress level.',
      };

  ActivityState get _activityState => widget.reading == null
      ? ActivityState.noSignal
      : activityStateFrom(
          posture: widget.reading!.posture,
          motionActivity: widget.reading!.motionActivity,
        );

  String _currentValue(SettingsController settings) {
    final r = widget.reading;
    return switch (widget.kind) {
      VitalKind.heartRate => r?.heartRateBpm?.toString() ?? '—',
      VitalKind.breathing => r?.respiratoryRateBpm?.toString() ?? '—',
      VitalKind.temperature => settings.formatTemperature(r?.bodyTemperatureC),
      VitalKind.activity => _activityState.label,
    };
  }

  String _unit(SettingsController settings) => switch (widget.kind) {
        VitalKind.heartRate => 'bpm',
        VitalKind.breathing => 'breaths/min',
        VitalKind.temperature => settings.temperatureUnitLabel,
        VitalKind.activity => '',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settings = SettingsScope.of(context);
    final range = _typicalRange(settings);
    final reading = widget.reading;

    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.label)),
      body: ListView(
        padding: const EdgeInsets.all(FurFeelTokens.space4),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.kind.icon, color: FurFeelTokens.brand),
                      const SizedBox(width: FurFeelTokens.space2),
                      Text('${widget.dog.name} right now'.toUpperCase(),
                          style: textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: FurFeelTokens.space3),
                  Row(
                    children: [
                      if (widget.kind == VitalKind.activity) ...[
                        ActivityIndicator(state: _activityState, size: 36),
                        const SizedBox(width: FurFeelTokens.space3),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              text: _currentValue(settings),
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                color: FurFeelTokens.ink,
                                height: 1.1,
                              ),
                              children: [
                                if (_unit(settings).isNotEmpty)
                                  TextSpan(
                                    text: ' ${_unit(settings)}',
                                    style: TextStyle(
                                      fontSize: FurFeelTokens.typeBodyMobileSize,
                                      fontWeight: FontWeight.w400,
                                      color: FurFeelTokens.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.kind == VitalKind.activity) ...[
                    const SizedBox(height: FurFeelTokens.space2),
                    Text(_activityState.description, style: textTheme.bodySmall),
                    if (reading?.motionActivity != null)
                      Text(
                        'Motion index ${reading!.motionActivity!.toStringAsFixed(1)} of 1',
                        style: textTheme.bodySmall,
                      ),
                  ],
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(
                    reading != null
                        ? 'Measured ${friendlyTimestamp(reading.capturedAt)}'
                        : 'Waiting for the next reading',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ).entrance(context),
          const SizedBox(height: FurFeelTokens.space3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TYPICAL AT REST', style: textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(range.value, style: textTheme.titleMedium),
                  const SizedBox(height: FurFeelTokens.space1),
                  Text(range.source, style: textTheme.bodySmall),
                ],
              ),
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: FurFeelTokens.space3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(FurFeelTokens.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT THIS MEANS', style: textTheme.labelSmall),
                  const SizedBox(height: FurFeelTokens.space2),
                  Text(_whatItMeans, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ).entrance(context, index: 2),
          const SizedBox(height: FurFeelTokens.space4),
          Text(
            'Typical ranges vary with breed, size, and age — your clinic can '
            'set ${widget.dog.name}\'s own baseline. Decision support, never '
            'a diagnosis.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ).entrance(context, index: 3),
        ],
      ),
    );
  }
}
