import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furfeel_mobile/models/activity_state.dart';
import 'package:furfeel_mobile/widgets/activity_indicator.dart';

void main() {
  group('activityStateFrom', () {
    test('maps each posture to its state', () {
      expect(activityStateFrom(posture: 'lying', motionActivity: 0.1),
          ActivityState.resting);
      expect(activityStateFrom(posture: 'sitting', motionActivity: 0.2),
          ActivityState.sitting);
      expect(activityStateFrom(posture: 'standing', motionActivity: 0.2),
          ActivityState.standing);
      expect(activityStateFrom(posture: 'moving', motionActivity: 0.4),
          ActivityState.moving);
    });

    test('moving splits on the classifier restless floor (0.6)', () {
      expect(activityStateFrom(posture: 'moving', motionActivity: 0.59),
          ActivityState.moving);
      expect(activityStateFrom(posture: 'moving', motionActivity: 0.6),
          ActivityState.veryActive);
      expect(activityStateFrom(posture: 'moving', motionActivity: 0.9),
          ActivityState.veryActive);
    });

    test('moving with no motion value stays plain moving', () {
      expect(activityStateFrom(posture: 'moving', motionActivity: null),
          ActivityState.moving);
    });

    test('unknown or missing posture falls back to intensity', () {
      expect(activityStateFrom(posture: 'unknown', motionActivity: 0.1),
          ActivityState.resting);
      expect(activityStateFrom(posture: null, motionActivity: 0.3),
          ActivityState.moving);
      expect(activityStateFrom(posture: null, motionActivity: 0.7),
          ActivityState.veryActive);
      expect(activityStateFrom(posture: null, motionActivity: null),
          ActivityState.noSignal);
    });

    test('every state has a word and a description', () {
      for (final state in ActivityState.values) {
        expect(state.label, isNotEmpty);
        expect(state.description, isNotEmpty);
      }
    });
  });

  group('ActivityIndicator', () {
    testWidgets('shows the paw for active states and sensors-off for no signal',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivityIndicator(state: ActivityState.sitting)),
        ),
      );
      expect(find.byIcon(Icons.pets), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivityIndicator(state: ActivityState.noSignal)),
        ),
      );
      expect(find.byIcon(Icons.sensors_off_outlined), findsOneWidget);
    });

    testWidgets('renders statically under reduced motion even when moving',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: ActivityIndicator(state: ActivityState.veryActive)),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      // No infinite animation scheduled: a plain pump settles with no
      // pending frames (would throw "Timer is still pending" otherwise).
      expect(find.byIcon(Icons.pets), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
