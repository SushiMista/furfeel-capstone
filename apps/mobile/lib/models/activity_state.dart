/// Owner-friendly activity state derived from the two motion signals the
/// harness sends (docs/07): `posture` (standing|sitting|lying|moving|unknown)
/// and `motion_activity` (0..1).
///
/// Thresholds reuse the classifier's existing cut-points from
/// packages/shared/classifier_config.json -- restless floor 0.6, resting
/// baseline 0.3 -- so Home never invents its own definition of "active"
/// (CLAUDE.md: no silent thresholds).
enum ActivityState { resting, sitting, standing, moving, veryActive, noSignal }

/// Classifier restless-tier floor (classifier_config.json motion_restlessness).
const double kVeryActiveMotionFloor = 0.6;

/// Global resting baseline for motion (classifier_config.json baselines).
const double kRestingMotionBaseline = 0.3;

ActivityState activityStateFrom({String? posture, double? motionActivity}) {
  switch (posture) {
    case 'lying':
      return ActivityState.resting;
    case 'sitting':
      return ActivityState.sitting;
    case 'standing':
      return ActivityState.standing;
    case 'moving':
      return (motionActivity ?? 0) >= kVeryActiveMotionFloor
          ? ActivityState.veryActive
          : ActivityState.moving;
    default:
      // No posture (older payloads / 'unknown'): fall back to intensity only.
      if (motionActivity == null) return ActivityState.noSignal;
      if (motionActivity >= kVeryActiveMotionFloor) return ActivityState.veryActive;
      if (motionActivity >= kRestingMotionBaseline) return ActivityState.moving;
      return ActivityState.resting;
  }
}

extension ActivityStateInfo on ActivityState {
  /// The word is the primary signal (docs/19: never color or motion alone).
  String get label => switch (this) {
        ActivityState.resting => 'Resting',
        ActivityState.sitting => 'Sitting',
        ActivityState.standing => 'Standing',
        ActivityState.moving => 'Moving',
        // Deliberately not the classifier's "restless": Home describes what
        // the dog is doing; the stress card does the worrying.
        ActivityState.veryActive => 'Very active',
        ActivityState.noSignal => 'No signal',
      };

  /// One-line owner explanation, used on the detail screen.
  String get description => switch (this) {
        ActivityState.resting => 'Lying down with little movement.',
        ActivityState.sitting => 'Sitting still.',
        ActivityState.standing => 'On their feet, not moving much.',
        ActivityState.moving => 'Up and walking around.',
        ActivityState.veryActive => 'Moving a lot right now.',
        ActivityState.noSignal => 'Waiting for the harness to report posture.',
      };
}
