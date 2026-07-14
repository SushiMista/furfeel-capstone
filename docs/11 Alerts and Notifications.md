---
title: "Alerts and Notifications"
type: feature-design
project: FurFeel
created: 2026-07-09
tags: [furfeel, alerts, notifications]
---

# Alerts and Notifications

## Alert Purpose
Alerts tell users when a dog's stress or readings require attention.

## Alert Triggers
- Stress level becomes Moderate Stress.
- Stress level becomes High Stress.
- Sensor reading exceeds safe configured threshold.
- Device stops sending data.
- Battery is low, if battery telemetry is available.

## Alert Severity
- Info: status update or recovered condition.
- Warning: mild or moderate concern.
- Critical: high stress or abnormal reading requiring immediate review.

## Alert Lifecycle
1. Created by backend.
2. Displayed in dashboard/mobile app.
3. Sent as notification if enabled.
4. Acknowledged by owner, staff, or veterinarian.
5. Resolved or kept in history.

## Related
- [[04 Mobile App Design]]
- [[05 Veterinary Dashboard Design]]
- [[08 AI Classification Pipeline]]
