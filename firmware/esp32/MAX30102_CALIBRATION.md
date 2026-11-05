# MAX30102 setup and OLED verification

Scope: telemetry/hardware follow-up to docs/03 Sprint 2 - Telemetry Checklist,
docs/06 IoT Wearable Device Design, docs/07 Sensor Data Pipeline and
docs/08 AI Classification Pipeline. Changes are limited to MAX acquisition,
OLED rendering and reading the existing telemetry response. No new classifier.

## Small-dog calibration

The current optical settings are retained engineering defaults, not a validated
small-dog preset. MAX_LED_CURRENT and MAX_CONTACT_IR_MIN are adjustable in
furfeel_sensor.ino. The 20-300 BPM acceptance bounds match docs/07 validation;
they do not define a normal pulse or stress category. The 5-second pulse timeout
and 30-second classification freshness timeout are display/acquisition choices.

Record the skin-contact location, sensor orientation, harness fit and dog ID.
Compare the displayed pulse with a simultaneous reference count/monitor on the
same dog while resting. Record repeated paired readings and signal/contact
failures. Do not compensate for poor contact by inventing a BPM offset. Choose
optical settings from measured signal quality and repeat the paired comparison
after refitting. Actual calibration remains pending these measurements.

## Manual hardware acceptance checks (not yet executed)

1. Compile/upload furfeel_sensor.ino as its own sketch with the existing libraries.
2. With MAX disconnected at startup, verify MAX:NOT FOUND and no heart-rate field.
3. With no skin contact, verify CHECK CONTACT, -- BPM and omitted heart-rate field.
4. With stable contact, verify WAITING FOR PULSE then PULSE DETECTED; compare BPM
   with the simultaneous reference. First beat only establishes timing.
5. Remove contact and replace it: the old average must clear. If contact remains
   but accepted beats stop, BPM must clear after five seconds of sensor servicing.
6. Exercise successful intake responses containing calm, mild, moderate and high
   on a test device; verify the respective OLED labels. Stress is the backend
   rule-v1 result, never inferred from MAX alone. Other sensors can still produce
   a classification when heart rate is absent.
7. Verify PENDING before a result, OFFLINE without Wi-Fi, and STALE after 30 s
   without a successful recognized classification. Unknown/error responses must
   not create a new label. Check all eight OLED rows fit the 128x64 display.
8. Verify IMU, respiration, temperature/humidity, battery and telemetry still work.

Known limitation: the existing firmware has blocking sampling/network operations.
Pulse timing and contact status need on-device validation; this change does not
rework unrelated scheduling or guarantee clinical accuracy.
