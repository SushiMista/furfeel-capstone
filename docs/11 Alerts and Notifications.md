---
title: "Alerts and Notifications"
type: feature-design
project: FurFeel
created: 2026-07-09
updated: 2026-07-17
tags: [furfeel, alerts, notifications]
---

# Alerts and Notifications

## Alert Purpose
Alerts tell users when a dog's stress or readings require attention.

## Alert Triggers (as built)
| type | trigger | severity | resolves |
|---|---|---|---|
| `moderate_stress` | stress level becomes Moderate | warning | acknowledge |
| `high_stress` | stress level becomes High | critical | acknowledge |
| `device_offline` | device stops sending data | warning | auto-resolves when the device checks back in |
| `low_battery` | battery ≤ **15% (provisional, tunable in `classifier_config.json` → `device_alerts.low_battery_percent`)** | warning | auto-resolves when battery reports above the threshold again |

Alerts dedupe against an existing OPEN alert of the same type, so a dog stuck at one state doesn't get a new row every telemetry tick. "Sensor reading exceeds safe configured threshold" (`out_of_range`) remains future work.

## Notification copy (QA pass)
All alert copy is **warm, plain, and observational** — it names the dog, says what the sensors observed, and suggests a simple check-in. Never diagnosis or causal claims; there is a test asserting this over the copy sources.

Examples (generated server-side in `services/edge/alerts/rules.ts`):
- "Biscuit seems a bit stressed — they're breathing fast. Maybe check on them when you can."
- "Biscuit seems quite stressed right now — it's warm and humid. Please check on them soon."
- "The harness battery is getting low (12%). Give it a charge soon so Biscuit's monitoring doesn't pause."

The "why" fragment maps the classifier's strongest logged reason to an owner phrase (`08 AI Classification Pipeline` reason table). This copy is used everywhere the alert appears: push (when FCM lands), the in-app alert list, and alert detail.

## Alert Severity
- Info: status update or recovered condition.
- Warning: mild or moderate concern, device health (offline / low battery).
- Critical: high stress requiring prompt review.

## Alert Lifecycle
1. Created by backend (telemetry-intake or the offline sweep).
2. Displayed in dashboard/mobile app (owner app groups: All / Stress / Harness — Harness covers `device_offline` + `low_battery`).
3. Sent as notification if enabled; per-type mute persists in `user_settings.muted_alert_types`.
4. Acknowledged by owner, staff, or veterinarian.
5. Resolved (device-health alerts auto-resolve on recovery) or kept in history.

## Related
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
- [[08 AI Classification Pipeline]]
